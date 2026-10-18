# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseBaleNotifications::BaleReplyMarkup do
  describe '.like_button' do
    let(:actor) { Fabricate(:user) }
    let(:author) { Fabricate(:user) }
    let(:target_post) { Fabricate(:post, user: author) }

    it 'shows like when no active like exists' do
      expect(described_class.like_button(target_post, actor)).to eq(
        text: I18n.t('discourse_bale_notifications.like'),
        callback_data: "like:#{target_post.id}"
      )
    end

    it 'returns to like after an existing like is removed' do
      PostActionCreator.create(actor, target_post, :like)

      expect(described_class.like_button(target_post, actor)).to eq(
        text: I18n.t('discourse_bale_notifications.unlike'),
        callback_data: "unlike:#{target_post.id}"
      )

      like_action = actor.post_actions.find_by!(
        post_id: target_post.id,
        post_action_type_id: PostActionType.types[:like],
        deleted_at: nil
      )
      like_action.remove_act!(actor)

      expect(described_class.like_button(target_post, actor)).to eq(
        text: I18n.t('discourse_bale_notifications.like'),
        callback_data: "like:#{target_post.id}"
      )
    end
  end
end
