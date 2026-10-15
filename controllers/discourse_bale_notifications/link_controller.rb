# frozen_string_literal: true

module DiscourseBaleNotifications
  # فاز یک - اصلاح #۸: کنترلر جداگانه برای اقدامات نیازمند ورود به حساب
  # دیسکورس (تولید/حذف کد اتصال). برخلاف BaleController که یک وب‌هوک عمومی
  # است، این کنترلر از رفتار پیش‌فرض احراز هویت دیسکورس استفاده می‌کند.
  class LinkController < ::ApplicationController
    requires_plugin DiscourseBaleNotifications::PLUGIN_NAME
    before_action :ensure_logged_in

    def create
      RateLimiter.new(current_user, 'bale-link-code-generate', 5, 10.minutes).performed!
      code = DiscourseBaleNotifications::LinkCode.generate_for(current_user)
      render json: { code: code, expires_in: DiscourseBaleNotifications::LinkCode::TTL_SECONDS }
    rescue RateLimiter::LimitExceeded => e
      render_json_error(e.description, status: 429)
    end

    def destroy
      UserCustomField.where(user_id: current_user.id, name: 'bale_chat_id').delete_all
      render json: success_json
    end
  end

end
