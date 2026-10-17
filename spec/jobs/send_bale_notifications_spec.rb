# frozen_string_literal: true

require 'rails_helper'

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
