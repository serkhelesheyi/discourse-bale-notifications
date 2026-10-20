# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::CleanupBaleActivityLog do
  describe '#execute' do
    it 'runs the activity-log retention cleanup through the shared reader' do
      expect(DiscourseBaleNotifications::BaleActivityLog).to receive(:recent_activity)

      described_class.new.execute({})
    end
  end
end
