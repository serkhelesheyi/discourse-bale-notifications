# frozen_string_literal: true

require 'time'

module DiscourseBaleNotifications
  # Stores a bounded, concurrency-safe history of notification API attempts.
  class BaleActivityLog
    RECORDABLE_METHODS = %w[sendMessage sendPhoto].freeze
    ACTIVITY_LOG_KEY = 'recent-activity'
    ACTIVITY_LOG_MAX_ENTRIES = 50
    ACTIVITY_LOG_RETENTION_SECONDS = 30 * 24 * 60 * 60
    ACTIVITY_LOG_MUTEX = 'bale-notifications-activity-log'

    def self.recent_activity
      DistributedMutex.synchronize(ACTIVITY_LOG_MUTEX) do
        log = PluginStore.get('bale-notifications', ACTIVITY_LOG_KEY) || []
        next [] unless log.is_a?(Array)

        retained_log = prune_expired_entries(log)
        PluginStore.set('bale-notifications', ACTIVITY_LOG_KEY, retained_log) if retained_log != log
        retained_log
      end
    end

    def self.record_activity(method_name, chat_id, success, error_code, description)
      return unless RECORDABLE_METHODS.include?(method_name)

      persist_entry(build_entry(method_name, chat_id, success, error_code, description))
    end

    def self.build_entry(method_name, chat_id, success, error_code, description)
      {
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
    end

    # Preserve entries with missing or malformed timestamps; expire only older valid timestamps.
    def self.prune_expired_entries(entries, now = Time.now.utc)
      cutoff = now - ACTIVITY_LOG_RETENTION_SECONDS
      entries.reject { |entry| expired_activity_entry?(entry, cutoff) }
    end

    def self.expired_activity_entry?(entry, cutoff)
      return false unless entry.is_a?(Hash)

      timestamp = entry['ts']
      return false if timestamp.blank?

      Time.iso8601(timestamp.to_s) < cutoff
    rescue ArgumentError, TypeError
      false
    end

    def self.persist_entry(entry)
      # Use the same mutex for reads and writes so pruning cannot race with
      # another worker's update and discard a newly recorded entry.
      DistributedMutex.synchronize(ACTIVITY_LOG_MUTEX) do
        log = PluginStore.get('bale-notifications', ACTIVITY_LOG_KEY)
        log = [] unless log.is_a?(Array)
        log = prune_expired_entries(log)
        log = ([entry] + log).first(ACTIVITY_LOG_MAX_ENTRIES)
        PluginStore.set('bale-notifications', ACTIVITY_LOG_KEY, log)
      end
    rescue StandardError => e
      # Activity logging is diagnostic and must never break message delivery.
      Rails.logger.warn("Bale notifications: failed to record activity log entry: #{e.class}: #{e.message}")
    end
  end
end
