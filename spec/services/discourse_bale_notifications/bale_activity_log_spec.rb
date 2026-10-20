# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseBaleNotifications::BaleActivityLog do
  describe '.record_activity' do
    it 'does not log exception messages when persisting activity fails' do
      sensitive_message = 'database failure with private payload do-not-log'
      allow(DistributedMutex).to receive(:synchronize)
        .with('bale-notifications-activity-log')
        .and_raise(StandardError, sensitive_message)

      expect(Rails.logger).to receive(:warn) do |message|
        expect(message).to include('StandardError')
        expect(message).not_to include(sensitive_message, 'private payload')
      end

      expect do
        described_class.record_activity('sendMessage', '987654321', false, nil, 'safe description')
      end.not_to raise_error
    end

    it 'ignores methods that are not recorded in the activity log' do
      expect(DistributedMutex).not_to receive(:synchronize)

      described_class.record_activity('getMe', nil, true, nil, nil)
    end
  end
end
