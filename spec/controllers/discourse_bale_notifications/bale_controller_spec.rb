# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseBaleNotifications::BaleController do
  describe '#reply_result_text' do
    it 'returns a Markdown link to the newly created reply' do
      result = double(errors: [], post: double(full_url: 'https://example.com/t/topic/123/4'))

      I18n.with_locale('en') do
        expect(described_class.new.send(:reply_result_text, result))
          .to eq('✅ Reply posted successfully. [View the reply](https://example.com/t/topic/123/4)')
      end
    end
  end

  describe '#escape_markdown' do
    it 'escapes Markdown punctuation in dynamic text' do
      expect(described_class.new.send(:escape_markdown, 'a_b *c* [d]'))
        .to eq('a\_b \*c\* \[d\]')
    end

    it 'returns an empty string for nil' do
      expect(described_class.new.send(:escape_markdown, nil)).to eq('')
    end
  end
end
