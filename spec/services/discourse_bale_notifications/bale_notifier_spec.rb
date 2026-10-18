# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseBaleNotifications::BaleNotifier do
  describe '.setup_webhook' do
    it 'places the webhook secret in the query string rather than the URL path' do
      allow(Discourse).to receive(:base_url).and_return('https://example.com')
      expect(described_class).to receive(:do_request).with(
        'setWebhook',
        { url: 'https://example.com/bale/hook?key=webhook-secret' }
      ).and_return(true)

      described_class.setup_webhook('webhook-secret')
    end
  end
end
