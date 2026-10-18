# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength -- Covers both allowed and blocked event-filter paths.
RSpec.describe DiscourseBaleNotifications::PluginSetup do
  describe '.register_notification_event' do
    let(:user) { Fabricate(:user) }
    let(:payload) { { notification_type: Notification.types[:mentioned] } }

    def register_and_capture_handler
      handler = nil
      allow(DiscourseEvent).to receive(:on).with(:push_notification) do |_event, &block|
        handler = block
      end

      described_class.register_notification_event
      handler
    end

    before do
      SiteSetting.bale_notifications_enabled = true
    end

    it 'enqueues Bale delivery when all Discourse push notification filters allow it' do
      filter = lambda do |candidate_user, candidate_payload|
        candidate_user == user && candidate_payload == payload
      end
      allow(DiscoursePluginRegistry).to receive(:push_notification_filters).and_return([filter])
      handler = register_and_capture_handler

      expect(Jobs).to receive(:enqueue).with(
        :send_bale_notifications,
        user_id: user.id,
        payload: payload
      )

      handler.call(user, payload)
    end

    it 'does not enqueue Bale delivery when a Discourse push notification filter blocks it' do
      filter = ->(_candidate_user, _candidate_payload) { false }
      allow(DiscoursePluginRegistry).to receive(:push_notification_filters).and_return([filter])
      handler = register_and_capture_handler

      expect(Jobs).not_to receive(:enqueue)

      handler.call(user, payload)
    end
  end
end
# rubocop:enable Metrics/BlockLength
