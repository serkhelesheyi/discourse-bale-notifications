# frozen_string_literal: true

require_dependency 'jobs/scheduled'

module Jobs
  # Periodically materializes the 30-day retention policy even when no admin
  # opens the activity page and no new notification is sent.
  class CleanupBaleActivityLog < ::Jobs::Scheduled
    every 1.day

    def execute(*)
      DiscourseBaleNotifications::BaleActivityLog.recent_activity
    end
  end
end
