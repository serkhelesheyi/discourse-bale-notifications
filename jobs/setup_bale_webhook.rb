# frozen_string_literal: true

require_dependency 'jobs/base'

module Jobs
  class SetupBaleWebhook < ::Jobs::Base
    def execute(*)
      if SiteSetting.bale_notifications_enabled?
        SiteSetting.bale_secret = SecureRandom.hex
        DiscourseBaleNotifications::BaleNotifier.setup_webhook(SiteSetting.bale_secret)
      else
        # فاز یک - اصلاح #۱۰: قبلاً هنگام غیرفعال‌سازی افزونه هیچ اقدامی
        # انجام نمی‌شد و وب‌هوک نزد بله ثبت‌شده باقی می‌ماند؛ بله تا ابد
        # سعی در ارسال درخواست به endpointِ اکنون ۴۰۴ می‌کرد. اکنون هنگام
        # غیرفعال‌سازی، وب‌هوک صراحتاً از سمت بله حذف می‌شود.
        DiscourseBaleNotifications::BaleNotifier.delete_webhook
      end
    end
  endend
