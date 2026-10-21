# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require 'rails_helper'

RSpec.describe 'Bale webhook', type: :request do
  before do
    SiteSetting.bale_notifications_enabled = true
    SiteSetting.bale_secret = 'test-webhook-secret'
  end

  describe 'POST /bale/hook?key=:key' do
    it 'returns JSON with forbidden status for an incorrect secret' do
      post '/bale/hook?key=wrong-secret', params: { message: {} }

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq('error' => 'forbidden')
    end

    it 'rejects requests when the configured webhook secret is blank' do
      SiteSetting.bale_secret = ''

      post '/bale/hook?key=test-webhook-secret', params: { message: {} }

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq('error' => 'forbidden')
    end

    it 'filters webhook secrets and payload content from Rails request logging' do
      post '/bale/hook?key=test-webhook-secret',
           params: {
             message: { text: 'private-webhook-message-do-not-log' },
             callback_query: { id: 'private-callback-id-do-not-log' },
             bale: { message: 'duplicate-private-payload-do-not-log' }
           }

      expect(response).to have_http_status(:ok)
      expect(request.filtered_path).not_to include('test-webhook-secret')
      filtered_parameters = request.filtered_parameters.to_json
      expect(filtered_parameters).to include('[FILTERED]')
      expect(filtered_parameters).not_to include(
        'test-webhook-secret',
        'private-webhook-message-do-not-log',
        'private-callback-id-do-not-log',
        'duplicate-private-payload-do-not-log'
      )
    end

    it 'acknowledges a message payload with no chat object without raising' do
      post '/bale/hook?key=test-webhook-secret', params: { message: { text: 'hello' } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'acknowledges a message payload with no chat ID without raising' do
      post '/bale/hook?key=test-webhook-secret',
           params: { message: { chat: { type: 'private' }, text: 'hello' } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'acknowledges non-private message payloads without processing them' do
      post '/bale/hook?key=test-webhook-secret',
           params: { message: { chat: { id: 123, type: 'group' }, text: 'hello' } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'ignores malformed message structures and non-scalar chat identifiers' do
      malformed_messages = [
        'not-an-object',
        [],
        { chat: 'not-an-object' },
        { chat: [] },
        { chat: { type: 'private' } },
        { chat: { id: [], type: 'private' } },
        { chat: { id: {}, type: 'private' } },
        { chat: { id: 123, type: 'group' } }
      ]

      DiscourseBaleNotifications::BaleNotifier.expects(:send_message).never

      malformed_messages.each do |message|
        post '/bale/hook?key=test-webhook-secret', params: { message: message }

        expect(response).to have_http_status(:ok), "unexpected status for message: #{message.inspect}"
        expect(response.parsed_body).to eq('success' => true)
      end
    end

    it 'logs only safe message shape details when webhook diagnostics are enabled' do
      SiteSetting.bale_notifications_webhook_diagnostics_enabled = true
      actor = Fabricate(:user)
      actor.custom_fields['bale_chat_id'] = '987654399'
      actor.save_custom_fields

      Rails.logger.expects(:info).once.with do |line|
        line.include?('[BaleNotifications diagnostic]') &&
          line.include?('"reply_to_message_present":false') &&
          line.include?('"text_present":true') &&
          !line.include?('987654399') &&
          !line.include?('private diagnostic text')
      end
      DiscourseBaleNotifications::BaleNotifier.expects(:send_message).with do |payload|
        payload[:chat_id] == '987654399' && payload[:text].include?('To reply')
      end

      post '/bale/hook?key=test-webhook-secret',
           params: {
             message: {
               text: 'private diagnostic text',
               chat: { id: 987_654_399, type: 'private' }
             }
           }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'answers and acknowledges a callback without a message object' do
      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).with(
        'callback-1',
        I18n.t('discourse_bale_notifications.action-unavailable')
      )

      post '/bale/hook?key=test-webhook-secret',
           params: { callback_query: { id: 'callback-1', data: 'like:1' } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'acknowledges malformed callback structures without performing actions' do
      malformed_callbacks = [
        'not-an-object',
        [],
        { id: 'callback-missing-message' },
        { id: 'callback-invalid-message', data: 'like:1', message: 'not-an-object' },
        { id: 'callback-invalid-chat', data: 'like:1', message: { chat: [] } },
        {
          id: 'callback-missing-message-id',
          data: 'like:1',
          message: { chat: { id: 123, type: 'private' } }
        },
        {
          id: 'callback-invalid-chat-id',
          data: 'like:1',
          message: { message_id: 1, chat: { id: [], type: 'private' } }
        },
        {
          id: 'callback-invalid-message-id',
          data: 'like:1',
          message: { message_id: {}, chat: { id: 123, type: 'private' } }
        },
        {
          id: [],
          data: 'like:1',
          message: { message_id: 1, chat: { id: 123, type: 'private' } }
        },
        {
          id: 'callback-invalid-action-type',
          data: ['like:1'],
          message: { message_id: 1, chat: { id: 123, type: 'private' } }
        }
      ]

      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).times(7)
      DiscourseBaleNotifications::BaleNotifier.expects(:edit_keyboard).never

      malformed_callbacks.each do |callback_query|
        post '/bale/hook?key=test-webhook-secret', params: { callback_query: callback_query }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('success' => true)
      end
    end

    it 'acknowledges a callback with malformed action data' do
      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).with(
        'callback-2',
        I18n.t('discourse_bale_notifications.action-unavailable')
      )

      post '/bale/hook?key=test-webhook-secret',
           params: {
             callback_query: {
               id: 'callback-2',
               data: 'like:not-an-id',
               message: {
                 message_id: 10,
                 chat: { id: 123, type: 'private' }
               }
             }
           }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'answers a valid callback from an unlinked chat without raising' do
      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).with(
        'callback-unlinked',
        I18n.t('discourse_bale_notifications.action-unavailable')
      )

      post '/bale/hook?key=test-webhook-secret',
           params: {
             callback_query: {
               id: 'callback-unlinked',
               data: 'like:1',
               message: {
                 message_id: 11,
                 chat: { id: 987_654_321, type: 'private' }
               }
             }
           }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'answers a callback for a deleted post without raising' do
      user = Fabricate(:user)
      user.custom_fields['bale_chat_id'] = '987654322'
      user.save_custom_fields

      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).with(
        'callback-deleted-post',
        I18n.t('discourse_bale_notifications.action-unavailable')
      )

      post '/bale/hook?key=test-webhook-secret',
           params: {
             callback_query: {
               id: 'callback-deleted-post',
               data: 'like:999999999',
               message: {
                 message_id: 12,
                 chat: { id: 987_654_322, type: 'private' }
               }
             }
           }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'likes the target post and refreshes the callback keyboard' do
      actor = Fabricate(:user)
      author = Fabricate(:user)
      target_post = Fabricate(:post, user: author)
      actor.custom_fields['bale_chat_id'] = '987654323'
      actor.save_custom_fields
      reply_markup = { inline_keyboard: [] }

      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).with(
        'callback-like',
        I18n.t('discourse_bale_notifications.like-success')
      )
      reply_markup_expectation =
        DiscourseBaleNotifications::BaleNotifier.expects(:generate_reply_markup)
      reply_markup_expectation.with(target_post, actor).returns(reply_markup)
      DiscourseBaleNotifications::BaleNotifier.expects(:edit_keyboard).with(
        {
          chat_id: '987654323',
          message_id: '13',
          reply_markup: reply_markup
        }
      )

      post '/bale/hook?key=test-webhook-secret',
           params: {
             callback_query: {
               id: 'callback-like',
               data: "like:#{target_post.id}",
               message: {
                 message_id: 13,
                 chat: { id: 987_654_323, type: 'private' }
               }
             }
           }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
      expect(
        actor.post_actions.exists?(
          post_id: target_post.id,
          post_action_type_id: PostActionType.types[:like],
          deleted_at: nil
        )
      ).to be(true)
    end

    it 'removes the existing like and refreshes the callback keyboard' do
      actor = Fabricate(:user)
      author = Fabricate(:user)
      target_post = Fabricate(:post, user: author)
      actor.custom_fields['bale_chat_id'] = '987654324'
      actor.save_custom_fields
      PostActionCreator.create(actor, target_post, :like)
      reply_markup = { inline_keyboard: [] }

      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).with(
        'callback-unlike',
        I18n.t('discourse_bale_notifications.unlike-success')
      )
      reply_markup_expectation =
        DiscourseBaleNotifications::BaleNotifier.expects(:generate_reply_markup)
      reply_markup_expectation.with(target_post, actor).returns(reply_markup)
      DiscourseBaleNotifications::BaleNotifier.expects(:edit_keyboard).with(
        {
          chat_id: '987654324',
          message_id: '14',
          reply_markup: reply_markup
        }
      )

      post '/bale/hook?key=test-webhook-secret',
           params: {
             callback_query: {
               id: 'callback-unlike',
               data: "unlike:#{target_post.id}",
               message: {
                 message_id: 14,
                 chat: { id: 987_654_324, type: 'private' }
               }
             }
           }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
      expect(
        actor.post_actions.exists?(
          post_id: target_post.id,
          post_action_type_id: PostActionType.types[:like],
          deleted_at: nil
        )
      ).to be(false)
    end

    it 'creates a forum reply from a reply to a stored Bale notification' do
      actor = Fabricate(:user)
      author = Fabricate(:user)
      target_post = Fabricate(:post, user: author)
      chat_id = 987_654_325
      bale_message_id = 15
      actor.custom_fields['bale_chat_id'] = chat_id.to_s
      actor.save_custom_fields
      PluginStore.set('bale-notifications', "message_#{chat_id}_#{bale_message_id}", target_post.id)

      reply_url = 'https://forum.example/t/example/1'
      reply_post = double(full_url: reply_url)
      result = double(errors: [], post: reply_post)
      manager = double(perform: result)
      expected_text = I18n.t(
        'discourse_bale_notifications.reply-success',
        post_url: CGI.escapeHTML(reply_url)
      )
      NewPostManager.expects(:new).with(
        actor,
        {
          raw: 'Reply from Bale',
          topic_id: target_post.topic_id,
          reply_to_post_number: target_post.post_number
        }
      ).returns(manager)
      DiscourseBaleNotifications::BaleNotifier.expects(:send_message).with(
        {
          chat_id: chat_id.to_s,
          text: expected_text,
          disable_web_page_preview: true
        }
      )

      post '/bale/hook?key=test-webhook-secret',
           params: {
             message: {
               text: 'Reply from Bale',
               chat: { id: chat_id, type: 'private' },
               reply_to_message: { message_id: bale_message_id }
             }
           }

      expect(expected_text).to include('[View the reply](https://forum.example/t/example/1)')
      expect(expected_text).not_to include('<a ')
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
    end

    it 'does not apply a callback action to a different linked account' do
      actor = Fabricate(:user)
      other_user = Fabricate(:user)
      author = Fabricate(:user)
      target_post = Fabricate(:post, user: author)
      actor.custom_fields['bale_chat_id'] = '987654326'
      actor.save_custom_fields
      other_user.custom_fields['bale_chat_id'] = '987654327'
      other_user.save_custom_fields
      reply_markup = { inline_keyboard: [] }

      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).with(
        'callback-account-isolation',
        I18n.t('discourse_bale_notifications.like-success')
      )
      reply_markup_expectation =
        DiscourseBaleNotifications::BaleNotifier.expects(:generate_reply_markup)
      reply_markup_expectation.with(target_post, actor).returns(reply_markup)
      DiscourseBaleNotifications::BaleNotifier.expects(:edit_keyboard).with(
        {
          chat_id: '987654326',
          message_id: '16',
          reply_markup: reply_markup
        }
      )

      post '/bale/hook?key=test-webhook-secret',
           params: {
             callback_query: {
               id: 'callback-account-isolation',
               data: "like:#{target_post.id}",
               message: {
                 message_id: 16,
                 chat: { id: 987_654_326, type: 'private' }
               }
             }
           }

      expect(response).to have_http_status(:ok)
      expect(
        actor.post_actions.exists?(
          post_id: target_post.id,
          post_action_type_id: PostActionType.types[:like],
          deleted_at: nil
        )
      ).to be(true)
      expect(
        other_user.post_actions.exists?(
          post_id: target_post.id,
          post_action_type_id: PostActionType.types[:like],
          deleted_at: nil
        )
      ).to be(false)
    end

    it 'acknowledges an unlike callback when the user has no active like' do
      actor = Fabricate(:user)
      author = Fabricate(:user)
      target_post = Fabricate(:post, user: author)
      actor.custom_fields['bale_chat_id'] = '987654328'
      actor.save_custom_fields
      reply_markup = { inline_keyboard: [] }

      DiscourseBaleNotifications::BaleNotifier.expects(:answer_callback).with(
        'callback-unlike-missing',
        I18n.t('discourse_bale_notifications.unlike-failed')
      )
      reply_markup_expectation =
        DiscourseBaleNotifications::BaleNotifier.expects(:generate_reply_markup)
      reply_markup_expectation.with(target_post, actor).returns(reply_markup)
      DiscourseBaleNotifications::BaleNotifier.expects(:edit_keyboard).with(
        {
          chat_id: '987654328',
          message_id: '17',
          reply_markup: reply_markup
        }
      )

      post '/bale/hook?key=test-webhook-secret',
           params: {
             callback_query: {
               id: 'callback-unlike-missing',
               data: "unlike:#{target_post.id}",
               message: {
                 message_id: 17,
                 chat: { id: 987_654_328, type: 'private' }
               }
             }
           }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true)
      expect(
        actor.post_actions.exists?(
          post_id: target_post.id,
          post_action_type_id: PostActionType.types[:like],
          deleted_at: nil
        )
      ).to be(false)
    end
  end
end

# rubocop:enable Metrics/BlockLength
