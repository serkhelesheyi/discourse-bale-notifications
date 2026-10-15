# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseBaleNotifications::BaleController do
  describe "#escape_html" do
    subject(:escape_html) { described_class.new.send(:escape_html, input) }

    context "when text contains HTML metacharacters" do
      let(:input) { %(<b>name & "value"</b>) }

      it "escapes the text rather than treating it as markup" do
        expect(escape_html).to eq("&lt;b&gt;name &amp; &quot;value&quot;&lt;/b&gt;")
      end
    end

    context "when the value is nil" do
      let(:input) { nil }

      it "returns an empty string" do
        expect(escape_html).to eq("")
      end
    end

    context "when text contains newlines" do
      let(:input) { "first line\nsecond line & more" }

      it "preserves line breaks while escaping markup characters" do
        expect(escape_html).to eq("first line\nsecond line &amp; more")
      end
    end
  end
end
