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

    it 'disables every notification type when the user explicitly deselects all types' do
      user.custom_fields['bale_notification_types'] = '__none__'
      user.save_custom_fields

      expect(job.user_notification_enabled?(user, 'mentioned')).to be(false)
      expect(job.user_notification_enabled?(user, 'replied')).to be(false)
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
      allow(user.user_option).to receive(:timezone).and_return('Invalid/Zone')
      allow(Time).to receive(:find_zone!).with('Invalid/Zone').and_raise(ArgumentError)

      expect(job.quiet_hours?(user)).to be(false)
    end
  end

  describe '#deliver_notification' do
    let(:post) { Fabricate(:post, user: user) }

    before do
      allow(job).to receive(:notification_text).and_return('rendered notification')
      allow(job).to receive(:avatar_url_for).and_return('https://example.com/avatar.png')
      allow(DiscourseBaleNotifications::BaleNotifier).to receive(:generate_reply_markup)
        .with(post, user)
        .and_return({ inline_keyboard: [] })
    end

    it 'passes quiet-hours suppression to the outgoing notification' do
      allow(job).to receive(:quiet_hours?).with(user).and_return(true)

      expect(DiscourseBaleNotifications::BaleNotifier).to receive(:send_notification).with(
        'rendered notification',
        '123456',
        { inline_keyboard: [] },
        avatar_url: 'https://example.com/avatar.png',
        disable_notification: true
      )

      job.deliver_notification(payload.merge(username: user.username), 'mentioned', user, '123456', post)
    end

    it 'keeps normal delivery notifications enabled outside quiet hours' do
      allow(job).to receive(:quiet_hours?).with(user).and_return(false)

      expect(DiscourseBaleNotifications::BaleNotifier).to receive(:send_notification).with(
        'rendered notification',
        '123456',
        { inline_keyboard: [] },
        avatar_url: 'https://example.com/avatar.png',
        disable_notification: false
      )

      job.deliver_notification(payload.merge(username: user.username), 'mentioned', user, '123456', post)
    end
  end

  describe '#delivery_context' do
    let(:post) { Fabricate(:post, user: user) }

    it 'skips a notification excluded by a persisted personal preference' do
      user.custom_fields['bale_notification_types'] = 'replied'
      user.save_custom_fields
      recipient = User.find(user.id)
      notification_payload = payload.merge(post_number: post.post_number, topic_id: post.topic_id)

      expect(
        job.delivery_context({ user_id: recipient.id }, notification_payload, 'mentioned')
      ).to be_nil
    end

    it 'delivers a selected notification using the persisted user preference' do
      user.custom_fields['bale_notification_types'] = 'mentioned|replied'
      user.save_custom_fields
      recipient = User.find(user.id)
      notification_payload = payload.merge(post_number: post.post_number, topic_id: post.topic_id)

      expect(
        job.delivery_context({ user_id: recipient.id }, notification_payload, 'mentioned')
      ).to eq([recipient, '123456', post])
    end

    it 'skips delivery when the persisted preference explicitly disables all types' do
      user.custom_fields['bale_notification_types'] = '__none__'
      user.save_custom_fields
      recipient = User.find(user.id)
      notification_payload = payload.merge(post_number: post.post_number, topic_id: post.topic_id)

      expect(
        job.delivery_context({ user_id: recipient.id }, notification_payload, 'mentioned')
      ).to be_nil
    end

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


  describe '#notification_text' do
    it 'uses a clear Markdown link and label for private-message notifications' do
      allow(user).to receive(:effective_locale).and_return('fa_IR')
      rendered = job.notification_text(
        {
          username: 'sender_name',
          topic_title: 'عنوان پیام خصوصی',
          post_url: '/t/private-topic/123/1',
          excerpt: 'متن پیام'
        },
        'private_message',
        user
      )

      expect(rendered).to include("موضوع پیام خصوصی: [عنوان پیام خصوصی](#{Discourse.base_url}/t/private-topic/123/1)")
      expect(rendered).to include('برای شما یک پیام خصوصی فرستاد')
      expect(rendered).not_to include('<a ', '<b>', '<pre>')
    end

    it 'escapes Markdown syntax in dynamic text' do
      expect(job.markdown_escape('a_b *c* [d]')).to eq('a\_b \*c\* \[d\]')
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
