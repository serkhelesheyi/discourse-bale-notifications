# frozen_string_literal: true

module DiscourseBaleNotifications
  # Handles validated inline-keyboard callbacks received by the Bale webhook.
  module WebhookCallbackHandler
    def handle_callback_query
      callback_payload = params['callback_query']
      unless valid_callback_payload?(callback_payload)
        callback_id = callback_payload['id'] if webhook_object?(callback_payload)
        if callback_id.present?
          DiscourseBaleNotifications::BaleNotifier.answer_callback(
            callback_id,
            I18n.t(
              'discourse_bale_notifications.action-unavailable',
              default: '❌ This action is no longer available.'
            )
          )
        end
        render json: { success: true }
        return
      end

      chat_id = params['callback_query']['message']['chat']['id']
      chat_type = params['callback_query']['message']['chat']['type']
      callback_id = params['callback_query']['id']

      # فاز یک - اصلاح #۹: دفاع در عمق، مشابه بخش پیام‌های معمولی.
      if chat_type.present? && chat_type != 'private'
        render json: { success: true }
        return
      end

      # فاز یک - اصلاح #۷ (بخش دوم): محدودسازی نرخ اقدامات هر چت.
      if rate_limited_chat?(chat_id)
        render json: { success: true }
        return
      end

      # توجه (فاز صفر - اصلاح بحرانی #۳):
      # قبلاً این بلوک هیچ rescue‌ای نداشت: اگر chat_id ناشناس بود
      # (UserCustomField پیدا نمی‌شد) یک NoMethodError روی `.user_id` روی nil،
      # و اگر پست حذف شده بود یک ActiveRecord::RecordNotFound رها می‌شد که
      # هیچ‌کدام گرفته نمی‌شدند => پاسخ ۵۰۰ بدون هیچ پاسخی به بله، و دکمه‌ی
      # کاربر در بله در حالت خطا/بارگذاری می‌ماند. اکنون هر دو حالت با یک
      # پیام قابل‌فهم به کاربر و بازگشت موفق (success: true) به بله مدیریت می‌شوند.
      begin
        user_custom_field = UserCustomField.find_by!(name: 'bale_chat_id', value: chat_id.to_s)
        user = User.find(user_custom_field.user_id)
        data = params['callback_query']['data'].to_s.split(':')
        post = Post.find(data[1])
      rescue ActiveRecord::RecordNotFound
        DiscourseBaleNotifications::BaleNotifier.answer_callback(
          callback_id,
          I18n.t(
            'discourse_bale_notifications.action-unavailable',
            default: '❌ This action is no longer available.'
          )
        )
        render json: { success: true }
        return
      end

      # فاز دو - اصلاح #۱۳: پیام‌های لایک/آنلایک هم با زبان کاربر ساخته می‌شوند.
      string = I18n.with_locale(user.effective_locale) do
        if data[0] == 'like'
          begin
            PostActionCreator.create(user, post, :like)
            I18n.t('discourse_bale_notifications.like-success')
          rescue PostAction::AlreadyActed
            I18n.t('discourse_bale_notifications.already-liked')
          rescue Discourse::InvalidAccess
            I18n.t('discourse_bale_notifications.like-failed')
          end

        elsif data[0] == 'unlike'
          begin
            guardian = Guardian.new(user)
            post_action_type_id = PostActionType.types[:like]
            post_action = user.post_actions.find_by(
              post_id: post.id,
              post_action_type_id: post_action_type_id,
              deleted_at: nil
            )
            raise Discourse::NotFound if post_action.blank?

            guardian.ensure_can_delete!(post_action)
            PostAction.remove_act(user, post, post_action_type_id)
            I18n.t('discourse_bale_notifications.unlike-success')
          rescue Discourse::NotFound, Discourse::InvalidAccess
            I18n.t('discourse_bale_notifications.unlike-failed')
          end
        else
          I18n.t('discourse_bale_notifications.action-unavailable', default: '❌ This action is no longer available.')
        end
      end

      # توجه: قبلاً در شاخه‌ی 'like' این متد یک‌بار اینجا و یک‌بار دوباره
      # بعد از if/elsif فراخوانی می‌شد (فراخوانی دوگانه‌ی answerCallback
      # برای بله)؛ اکنون فقط یک‌بار و به‌صورت یکنواخت برای هر سه حالت
      # (like/unlike/نامعتبر) صدا زده می‌شود.
      DiscourseBaleNotifications::BaleNotifier.answer_callback(callback_id, string)

      message = {
        chat_id: chat_id,
        message_id: params['callback_query']['message']['message_id'],
        reply_markup: DiscourseBaleNotifications::BaleNotifier.generate_reply_markup(post, user)
      }
      DiscourseBaleNotifications::BaleNotifier.edit_keyboard(message)
    end
  end
end
