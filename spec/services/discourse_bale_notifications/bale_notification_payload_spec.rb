# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseBaleNotifications::BaleNotificationPayload do
  # rubocop:disable Metrics/BlockLength -- Keep payload contract examples together.
  describe '.photo?' do
    before { allow(SiteSetting).to receive(:bale_notifications_show_avatar?).and_return(true) }

    it 'requires the site setting and a nonblank avatar URL' do
      allow(SiteSetting).to receive(:bale_notifications_show_avatar?).and_return(false)
      expect(described_class.photo?('message', 'https://example.com/avatar.png')).to be(false)

      allow(SiteSetting).to receive(:bale_notifications_show_avatar?).and_return(true)
      expect(described_class.photo?('message', nil)).to be(false)
      expect(described_class.photo?('message', 'https://example.com/avatar.png')).to be(true)
    end

    it 'uses a photo only when the caption fits the API limit' do
      avatar = 'https://example.com/avatar.png'

      expect(described_class.photo?('a' * 1024, avatar)).to be(true)
      expect(described_class.photo?('a' * 1025, avatar)).to be(false)
    end
  end

  describe '.text' do
    it 'includes the selected chat, HTML mode, reply markup and quiet-hours flag' do
      result = described_class.text('hello', '123456', { inline_keyboard: [] }, true)

      expect(result).to eq(
        chat_id: '123456',
        text: 'hello',
        parse_mode: 'html',
        disable_web_page_preview: true,
        disable_notification: true,
        reply_markup: { inline_keyboard: [] }
      )
    end
  end

  describe '.photo' do
    it 'includes the selected chat, caption, reply markup and quiet-hours flag' do
      result = described_class.photo(
        'caption',
        '123456',
        { inline_keyboard: [] },
        'https://example.com/avatar.png',
        false
      )

      expect(result).to eq(
        chat_id: '123456',
        photo: 'https://example.com/avatar.png',
        caption: 'caption',
        parse_mode: 'html',
        disable_notification: false,
        reply_markup: { inline_keyboard: [] }
      )
    end
  end
  # rubocop:enable Metrics/BlockLength
end
