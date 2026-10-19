# frozen_string_literal: true

module DiscourseBaleNotifications
  # فاز سه - اصلاح #۱۵: کنترلر پنل وضعیت مدیریتی. فقط برای ادمین (از طریق
  # کلاس پایه‌ی استاندارد Admin::AdminController که بررسی ادمین‌بودن را خودش
  # انجام می‌دهد، دقیقاً مثل بقیه‌ی صفحات /admin/* در دیسکورس).
  # Admin-only status and test-message endpoints for the plugin.
  class AdminController < ::Admin::AdminController
    requires_plugin DiscourseBaleNotifications::PLUGIN_NAME

    def index
      render html: '', layout: 'admin'
    end

    def status
      activity = DiscourseBaleNotifications::BaleNotifier.recent_activity

      render json: {
        enabled: SiteSetting.bale_notifications_enabled?,
        linked_users_count: UserCustomField.where(name: 'bale_chat_id').count,
        recent_activity: activity_with_usernames(activity),
        webhook_info: redacted_webhook_info
      }
    end

    def activity_with_usernames(activity)
      usernames = usernames_by_chat_id(activity)
      activity.map do |entry|
        entry.except('chat_id').merge('username' => usernames[entry['chat_id'].to_s])
      end
    end

    def usernames_by_chat_id(activity)
      chat_ids = activity.map { |entry| entry['chat_id'] }.compact.map(&:to_s).uniq
      return {} if chat_ids.blank?

      UserCustomField
        .joins('INNER JOIN users ON users.id = user_custom_fields.user_id')
        .where(name: 'bale_chat_id', value: chat_ids)
        .pluck('user_custom_fields.value', 'users.username')
        .to_h
    end

    def redacted_webhook_info
      info = DiscourseBaleNotifications::BaleNotifier.fetch_webhook_info
      return info unless info.is_a?(Hash) && info['result'].is_a?(Hash) && info['result']['url'].present?

      info = info.deep_dup
      registered_url = info['result']['url'].to_s
      redacted_url = registered_url.sub(/([?&]key=)[^&#]+/, '\\1[REDACTED]')
      info['result']['url'] = redacted_url == registered_url ? '[URL hidden]' : redacted_url
      info
    end

    def test
      target_user = find_test_user
      return render_user_not_found unless target_user

      chat_id = target_user.custom_fields['bale_chat_id']
      return render_user_not_linked if chat_id.blank?
      return render json: success_json if send_test_message(target_user, chat_id)

      render_test_failure
    end

    def find_test_user
      User.find_by(username: params[:username].to_s.strip)
    end

    def render_user_not_found
      render_json_error(I18n.t('discourse_bale_notifications.admin.user_not_found'), status: 404)
    end

    def render_user_not_linked
      render_json_error(I18n.t('discourse_bale_notifications.admin.user_not_linked'), status: 422)
    end

    def render_test_failure
      render_json_error(I18n.t('discourse_bale_notifications.admin.test_failed'), status: 502)
    end

    def send_test_message(target_user, chat_id)
      test_text = I18n.with_locale(target_user.effective_locale) do
        I18n.t('discourse_bale_notifications.admin.test_message', site_title: CGI.escapeHTML(SiteSetting.title))
      end

      DiscourseBaleNotifications::BaleNotifier.send_message(
        { chat_id: chat_id, text: test_text, parse_mode: 'html' }
      )
    end
  end
end
