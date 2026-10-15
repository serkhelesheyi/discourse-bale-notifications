# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../services/discourse_bale_notifications/link_code'

RSpec.describe DiscourseBaleNotifications::LinkCode do
  describe '.consume' do
    it 'returns nil for inputs that are not six decimal digits' do
      expect(Discourse.redis).not_to receive(:eval)

      expect(described_class.consume(nil)).to be_nil
      expect(described_class.consume('')).to be_nil
      expect(described_class.consume('12345')).to be_nil
      expect(described_class.consume('1234567')).to be_nil
      expect(described_class.consume('12a456')).to be_nil
    end

    it 'consumes a code only once' do
      user = Struct.new(:id).new(123_456)
      code = described_class.generate_for(user)

      expect(described_class.consume(code)).to eq(123_456)
      expect(described_class.consume(code)).to be_nil
    end

    it 'allows only one concurrent consumer to obtain the user id' do
      user = Struct.new(:id).new(654_321)
      code = described_class.generate_for(user)

      results = 12.times.map { Thread.new { described_class.consume(code) } }.map(&:value)

      expect(results.count(654_321)).to eq(1)
      expect(results.compact).to eq([654_321])
    end
  end
end
