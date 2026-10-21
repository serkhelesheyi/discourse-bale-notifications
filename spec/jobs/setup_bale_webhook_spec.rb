# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength -- Setup-job regression cases share one concise fixture.
RSpec.describe Jobs::SetupBaleWebhook do
  subject(:job) { described_class.new }

  before do
    allow(Rails.logger).to receive(:error)
  end

  describe 'Sidekiq retry policy' do
    it 'keeps webhook operation retries bounded at five' do
      expect(described_class.get_sidekiq_options['retry']).to eq(5)
    end
  end

  describe 'transient failures' do
    before do
      allow(SiteSetting).to receive(:bale_secret).and_return('existing-secret')
    end

    it 'raises a retryable error for a transient API error code during registration' do
      allow(SiteSetting).to receive(:bale_notifications_enabled?).and_return(true)
      allow(DiscourseBaleNotifications::BaleNotifier).to receive(:setup_webhook)
        .and_return('ok' => false, 'error_code' => 503, '_bale_http_status' => 200)

      expect { job.execute }
        .to raise_error(DiscourseBaleNotifications::RetryableWebhookOperation::Error, /registration.*error_code=503/)
    end

    it 'raises a retryable error for a transient HTTP status during removal' do
      allow(SiteSetting).to receive(:bale_notifications_enabled?).and_return(false)
      allow(DiscourseBaleNotifications::BaleNotifier).to receive(:delete_webhook)
        .and_return('ok' => false, 'error_code' => 400, '_bale_http_status' => 503)

      expect { job.execute }
        .to raise_error(DiscourseBaleNotifications::RetryableWebhookOperation::Error, /removal.*http_status=503/)
    end

    it 'raises a retryable error for a known transport failure' do
      allow(SiteSetting).to receive(:bale_notifications_enabled?).and_return(true)
      allow(DiscourseBaleNotifications::BaleNotifier).to receive(:setup_webhook)
        .and_return('ok' => false, '_bale_transport_failure' => true)

      expect { job.execute }
        .to raise_error(DiscourseBaleNotifications::RetryableWebhookOperation::Error, /transport layer/)
    end
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

      it 'creates a secret only when none exists and stops on a permanent registration failure' do
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

        expect { job.execute }.not_to raise_error
      end

      it 'logs a safe failure when the API permanently rejects registration' do
        allow(SiteSetting).to receive(:bale_secret).and_return('existing-secret')
        allow(DiscourseBaleNotifications::BaleNotifier).to receive(:setup_webhook)
          .with('existing-secret')
          .and_return('ok' => false, 'description' => 'simulated failure')

        expect(Rails.logger).to receive(:error).with(
          'Bale webhook registration failed; the current webhook secret was retained'
        )

        expect { job.execute }.not_to raise_error
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

      it 'logs a safe failure when webhook removal is permanently rejected' do
        allow(DiscourseBaleNotifications::BaleNotifier).to receive(:delete_webhook)
          .and_return(false)

        expect(Rails.logger).to receive(:error).with('Bale webhook removal failed')

        expect { job.execute }.not_to raise_error
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
