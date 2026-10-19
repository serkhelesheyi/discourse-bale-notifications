# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength -- Setup-job regression cases share one concise fixture.
RSpec.describe Jobs::SetupBaleWebhook do
  subject(:job) { described_class.new }

  before do
    allow(Rails.logger).to receive(:error)
  end

  describe '#execute' do
    context 'when Bale notifications are enabled' do
      before do
        allow(SiteSetting).to receive(:bale_notifications_enabled?).and_return(true)
      end

      it 'reuses the current secret when registering the webhook' do
        allow(SiteSetting).to receive(:bale_secret).and_return('existing-secret')
        expect(SiteSetting).not_to receive(:bale_secret=)
        expect(DiscourseBaleNotifications::BaleNotifier).to receive(:setup_webhook)
          .with('existing-secret')
          .and_return('ok' => true)

        job.execute
      end

      it 'creates a secret only when none exists and raises on registration failure' do
        allow(SiteSetting).to receive(:bale_secret).and_return('')
        allow(SecureRandom).to receive(:hex).and_return('new-stable-secret')

        expect(SiteSetting).to receive(:bale_secret=).with('new-stable-secret').ordered
        expect(DiscourseBaleNotifications::BaleNotifier).to receive(:setup_webhook)
          .with('new-stable-secret')
          .ordered
          .and_return(false)
        expect(Rails.logger).to receive(:error).with(
          'Bale webhook registration failed; the current webhook secret was retained'
        )

        expect { job.execute }.to raise_error(StandardError, 'Bale webhook registration failed')
      end

      it 'raises a safe error when the API does not confirm registration' do
        allow(SiteSetting).to receive(:bale_secret).and_return('existing-secret')
        allow(DiscourseBaleNotifications::BaleNotifier).to receive(:setup_webhook)
          .with('existing-secret')
          .and_return('ok' => false, 'description' => 'simulated failure')

        expect(Rails.logger).to receive(:error).with(
          'Bale webhook registration failed; the current webhook secret was retained'
        )

        expect { job.execute }.to raise_error(StandardError, 'Bale webhook registration failed')
      end
    end

    context 'when Bale notifications are disabled' do
      before do
        allow(SiteSetting).to receive(:bale_notifications_enabled?).and_return(false)
      end

      it 'removes the webhook when the API confirms success' do
        expect(DiscourseBaleNotifications::BaleNotifier).to receive(:delete_webhook)
          .and_return('ok' => true)
        expect(Rails.logger).not_to receive(:error)

        job.execute
      end

      it 'raises a safe error when webhook removal is not confirmed' do
        allow(DiscourseBaleNotifications::BaleNotifier).to receive(:delete_webhook)
          .and_return(false)

        expect(Rails.logger).to receive(:error).with('Bale webhook removal failed')

        expect { job.execute }.to raise_error(StandardError, 'Bale webhook removal failed')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
