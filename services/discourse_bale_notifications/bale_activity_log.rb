# frozen_string_literal: true

module DiscourseBaleNotifications
  # Stores a bounded, concurrency-safe history of notification API attempts.
  class BaleActivityLog
    RECORDABLE_METHODS = %w[sendMessage sendPhoto].freeze
    ACTIVITY_LOG_KEY = 'recent-activity'
    ACTIVITY_LOG_MAX_ENTRIES = 50
  
    def self.recent_activity
      PluginStore.get('bale-notifications', ACTIVITY_LOG_KEY) || []
    end
  
    def self.record_activity(method_name, chat_id, success, error_code, description)
      return unless RECORDABLE_METHODS.include?(method_name)
  
      entry = {
        # ISO8601 UTC به‌جای timestamp خام عددی ذخیره می‌شود تا در نمایش
        # فرانت‌اند نیازی به حدس زدن واحد (ثانیه/میلی‌ثانیه) نباشد و ریسک
        # نمایش اشتباه تاریخ از بین برود.
        'ts' => Time.now.utc.iso8601,
        'method' => method_name,
        'chat_id' => chat_id,
        'ok' => success,
        'error_code' => error_code,
        'description' => description
      }
  
      # DistributedMutex چون چند Worker سیدکیک ممکن است هم‌زمان بخواهند این
      # لیست مشترک را بخوانند-و-بنویسند؛ بدون قفل، آخرین نویسنده می‌توانست
      # نوشته‌ی نویسنده‌ی دیگر را از دست بدهد (race condition کلاسیک read-modify-write).
      DistributedMutex.synchronize('bale-notifications-activity-log') do
        log = PluginStore.get('bale-notifications', ACTIVITY_LOG_KEY) || []
        log = ([entry] + log).first(ACTIVITY_LOG_MAX_ENTRIES)
        PluginStore.set('bale-notifications', ACTIVITY_LOG_KEY, log)
      end
    rescue StandardError => e
      # ثبت لاگ فعالیت (یک قابلیت صرفاً تشخیصی) هرگز نباید باعث شکست ارسال
      # واقعی پیام شود؛ به همین دلیل اینجا rescue عمومی توجیه‌پذیر است.
      Rails.logger.warn("Bale notifications: failed to record activity log entry: #{e.class}: #{e.message}")
    end
  
  end
end
