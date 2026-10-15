# frozen_string_literal: true

module DiscourseBaleNotifications
  # فاز سه - اصلاح #۱۵: کنترلر پنل وضعیت مدیریتی. فقط برای ادمین (از طریق
  # کلاس پایه‌ی استاندارد Admin::AdminController که بررسی ادمین‌بودن را خودش
  # انجام می‌دهد، دقیقاً مثل بقیه‌ی صفحات /admin/* در دیسکورس).
  class AdminController < ::Admin::AdminController
    requires_plugin DiscourseBaleNotifications::PLUGIN_NAME

    def index
      render html: '', layout: 'admin'
    end

    def status
      linked_count = UserCustomField.where(name: 'bale_chat_id').count
      activity = DiscourseBaleNotifications::BaleNotifier.recent_activity

      chat_ids = activity.map { |entry| entry['chat_id'] }.compact.map(&:to_s).uniq
      usernames_by_chat_id =
        if chat_ids.present?
          UserCustomField
            .joins('INNER JOIN users ON users.id = user_custom_fields.user_id')
            .where(name: 'bale_chat_id', value: chat_ids)
            .pluck('user_custom_fields.value', 'users.username')
            .to_h
        else
          {}
        end

      activity_with_usernames = activity.map do |entry|
        entry.merge('username' => usernames_by_chat_id[entry['chat_id'].to_s])
      end

      # فراخوانی زنده‌ی getWebhookInfo تا ادمین وضعیت واقعی سمت بله را ببیند،
      # نه فقط آن‌چه در دیتابیس محلی داریم.
      webhook_info = DiscourseBaleNotifications::BaleNotifier.fetch_webhook_info

      # URL برگشتی API بله شامل secret مسیر /bale/hook/:key است.
      # پنل وضعیت فقط به مسیر ثبت‌شده نیاز دارد؛ secret نباید در پاسخ JSON
      # قابل مشاهده برای مدیران نمایش داده شود.
      if webhook_info.is_a?(Hash) && webhook_info['result'].is_a?(Hash) &&
         webhook_info['result']['url'].present?
        webhook_info = webhook_info.deep_dup
        registered_url = webhook_info['result']['url'].to_s
        redacted_url = registered_url.sub(%r{(/bale/hook/)[^/?#]+}, '\\1[REDACTED]')
        webhook_info['result']['url'] =
          redacted_url == registered_url ? '[URL hidden]' : redacted_url
      end

      render json: {
        enabled: SiteSetting.bale_notifications_enabled?,
        linked_users_count: linked_count,
        recent_activity: activity_with_usernames,
        webhook_info: webhook_info
      }
    end

    def test
      username = params[:username].to_s.strip
      target_user = username.present? ? User.find_by(username: username) : nil

      if target_user.nil?
        return render_json_error(I18n.t('discourse_bale_notifications.admin.user_not_found'), status: 404)
      end

      chat_id = target_user.custom_fields['bale_chat_id']
      if chat_id.blank?
        return render_json_error(I18n.t('discourse_bale_notifications.admin.user_not_linked'), status: 422)
      end

      test_text = I18n.with_locale(target_user.effective_locale) do
        I18n.t('discourse_bale_notifications.admin.test_message', site_title: CGI.escapeHTML(SiteSetting.title))
      end

      response = DiscourseBaleNotifications::BaleNotifier.send_message(
        {
          chat_id: chat_id,
          text: test_text,
          parse_mode: 'html'
        }
      )

      if response
        render json: success_json
      else
        render_json_error(I18n.t('discourse_bale_notifications.admin.test_failed'), status: 502)
      end
    end
  end

end
