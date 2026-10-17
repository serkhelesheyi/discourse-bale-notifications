# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength -- Covers stale jobs and malformed API results together.
RSpec.describe Jobs::SendBaleNotifications do
  subject(:job) { described_class.new }

  let(:user) { Fabricate(:user) }
  let(:payload) do
    {
      post_number: 999_999,
      topic_id: 999_999,
      notification_type: Notification.types[:mentioned]
    }
  end

  before do
    user.custom_fields['bale_chat_id'] = '123456'
    user.save_custom_fields
  end

  describe '#site_notification_enabled?' do
    it 'accepts only notification types in the site allowlist' do
      SiteSetting.bale_enabled_notification_types = 'mentioned|replied'

      expect(job.site_notification_enabled?('mentioned')).to be(true)
      expect(job.site_notification_enabled?('chat_message')).to be(false)
    end
  end


  describe '#user_notification_enabled?' do
    it 'preserves the legacy default when no personal preference is stored' do
      expect(job.user_notification_enabled?(user, 'mentioned')).to be(true)
      expect(job.user_notification_enabled?(user, 'replied')).to be(true)
    end

    it 'allows only explicitly selected types when a personal preference is stored' do
      user.custom_fields['bale_notification_types'] = 'mentioned|replied'
      user.save_custom_fields

      expect(job.user_notification_enabled?(user, 'mentioned')).to be(true)
      expect(job.user_notification_enabled?(user, 'replied')).to be(true)
      expect(job.user_notification_enabled?(user, 'quoted')).to be(false)
      expect(job.user_notification_enabled?(user, 'unknown_legacy_type')).to be(false)
    end

    it 'treats an empty preference as the legacy unrestricted setting' do
      user.custom_fields['bale_notification_types'] = ''
      user.save_custom_fields

      expect(job.user_notification_enabled?(user, 'quoted')).to be(true)
    end
  end

  describe '#quiet_hours_for_hour?' do
    it 'handles a quiet-hours interval that crosses midnight' do
      SiteSetting.bale_notifications_quiet_hours_start = 22
      SiteSetting.bale_notifications_quiet_hours_end = 8

      [22, 23, 0, 7].each do |hour|
        expect(job.quiet_hours_for_hour?(hour)).to be(true), "expected hour #{hour} to be quiet"
      end
      [8, 12, 21].each do |hour|
        expect(job.quiet_hours_for_hour?(hour)).to be(false), "expected hour #{hour} not to be quiet"
      end
    end

    it 'uses an inclusive start and exclusive end for a same-day interval' do
      SiteSetting.bale_notifications_quiet_hours_start = 9
      SiteSetting.bale_notifications_quiet_hours_end = 17

      expect(job.quiet_hours_for_hour?(8)).to be(false)
      expect(job.quiet_hours_for_hour?(9)).to be(true)
      expect(job.quiet_hours_for_hour?(16)).to be(true)
      expect(job.quiet_hours_for_hour?(17)).to be(false)
    end

    it 'disables quiet hours when start and end are equal' do
      SiteSetting.bale_notifications_quiet_hours_start = 8
      SiteSetting.bale_notifications_quiet_hours_end = 8

      expect(job.quiet_hours_for_hour?(8)).to be(false)
      expect(job.quiet_hours_for_hour?(23)).to be(false)
    end
  end

  describe '#quiet_hours?' do
    it 'does not silence notifications when the site setting is disabled' do
      SiteSetting.bale_notifications_quiet_hours_enabled = false
      expect(job.quiet_hours?(user)).to be(false)
    end

    it 'uses the recipient user timezone when deciding whether to silence a notification' do
      SiteSetting.bale_notifications_quiet_hours_enabled = true
      SiteSetting.bale_notifications_quiet_hours_start = 22
      SiteSetting.bale_notifications_quiet_hours_end = 8
      user.user_option.update!(timezone: 'UTC')
      zone = double('time zone', now: double(hour: 23))
      allow(Time).to receive(:find_zone!).with('UTC').and_return(zone)

      expect(job.quiet_hours?(user)).to be(true)
    end

    it 'fails open if the configured timezone cannot be resolved' do
      SiteSetting.bale_notifications_quiet_hours_enabled = true
      user.user_option.update!(timezone: 'Invalid/Zone')
      allow(Time).to receive(:find_zone!).with('Invalid/Zone').and_raise(ArgumentError)

      expect(job.quiet_hours?(user)).to be(false)
    end
  end

  describe '#delivery_context' do
    it 'skips a notification when its post no longer exists' do
      allow(Post).to receive(:find_by)
        .with(post_number: payload[:post_number], topic_id: payload[:topic_id])
        .and_return(nil)

      expect(job.delivery_context({ user_id: user.id }, payload, 'mentioned')).to be_nil
    end

    it 'skips a queued notification when its user no longer exists' do
      missing_user_id = 9_999_999
      expect(User).to receive(:find).with(missing_user_id).and_raise(ActiveRecord::RecordNotFound)

      expect(job.delivery_context({ user_id: missing_user_id }, payload, 'mentioned')).to be_nil
    end
  end

  describe '#store_message_id' do
    it 'ignores incomplete API responses and missing posts' do
      expect(PluginStore).not_to receive(:set)

      expect { job.store_message_id({ 'ok' => true }, '123456', nil) }.not_to raise_error
    end
  end
end
# rubocop:enable Metrics/BlockLength
