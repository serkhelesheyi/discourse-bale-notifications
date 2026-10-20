# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe DiscourseBaleNotifications::BaleActivityLog do
  let(:store_name) { 'bale-notifications' }
  let(:store_key) { described_class::ACTIVITY_LOG_KEY }
  let(:mutex_key) { described_class::ACTIVITY_LOG_MUTEX }
  let(:now) { Time.utc(2026, 10, 20, 10, 0, 0) }

  before do
    allow(Time).to receive(:now).and_return(now)
    allow(DistributedMutex).to receive(:synchronize).with(mutex_key).and_yield
  end

  describe '.recent_activity' do
    it 'removes entries older than 30 days and preserves boundary and unparseable timestamps' do
      expired = { 'ts' => (now - described_class::ACTIVITY_LOG_RETENTION_SECONDS - 1).iso8601 }
      boundary = { 'ts' => (now - described_class::ACTIVITY_LOG_RETENTION_SECONDS).iso8601 }
      malformed = { 'ts' => 'not-a-timestamp' }
      missing_timestamp = { 'method' => 'sendMessage' }
      entries = [expired, boundary, malformed, missing_timestamp]
      retained = [boundary, malformed, missing_timestamp]

      allow(PluginStore).to receive(:get).with(store_name, store_key).and_return(entries)
      expect(PluginStore).to receive(:set).with(store_name, store_key, retained)

      expect(described_class.recent_activity).to eq(retained)
    end

    it 'does not rewrite the store when no entries have expired' do
      entries = [
        { 'ts' => (now - 60).iso8601 },
        { 'ts' => 'legacy-invalid-timestamp' }
      ]
      allow(PluginStore).to receive(:get).with(store_name, store_key).and_return(entries)
      expect(PluginStore).not_to receive(:set)

      expect(described_class.recent_activity).to eq(entries)
    end

    it 'returns an empty list without overwriting a malformed stored value' do
      allow(PluginStore).to receive(:get).with(store_name, store_key).and_return('unexpected-value')
      expect(PluginStore).not_to receive(:set)

      expect(described_class.recent_activity).to eq([])
    end
  end

  describe '.persist_entry' do
    it 'prunes expired entries before adding a new entry and retains at most 50 entries' do
      expired = { 'ts' => (now - described_class::ACTIVITY_LOG_RETENTION_SECONDS - 1).iso8601 }
      recent_entries = 50.times.map do |index|
        { 'ts' => (now - index).iso8601, 'method' => 'sendMessage', 'index' => index }
      end
      allow(PluginStore).to receive(:get).with(store_name, store_key).and_return([expired] + recent_entries)

      new_entry = { 'ts' => now.iso8601, 'method' => 'sendPhoto', 'marker' => 'new' }
      expect(PluginStore).to receive(:set) do |name, key, saved_entries|
        expect(name).to eq(store_name)
        expect(key).to eq(store_key)
        expect(saved_entries.length).to eq(described_class::ACTIVITY_LOG_MAX_ENTRIES)
        expect(saved_entries.first).to eq(new_entry)
        expect(saved_entries).not_to include(expired)
        expect(saved_entries.map { |entry| entry['index'] }).to eq((0..48).to_a)
      end

      described_class.persist_entry(new_entry)
    end
  end

  describe '.record_activity' do
    it 'does not persist methods outside the allowlist' do
      expect(DistributedMutex).not_to receive(:synchronize)
      expect(PluginStore).not_to receive(:get)
      expect(PluginStore).not_to receive(:set)

      described_class.record_activity('getMe', nil, true, nil, nil)
    end
  end
end
# rubocop:enable Metrics/BlockLength
