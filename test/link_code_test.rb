# frozen_string_literal: true

require "minitest/autorun"
require "securerandom"

# Minimal ActiveSupport compatibility for exercising this service outside Discourse.
class String
  def blank?
    strip.empty?
  end unless method_defined?(:blank?)
end

module Discourse
  def self.redis
    @redis ||= FakeRedis.new
  end

  def self.redis=(redis)
    @redis = redis
  end
end

class FakeRedis
  attr_reader :entries, :last_set_options

  def initialize
    @entries = {}
  end

  def set(key, value, nx: false, ex: nil)
    @last_set_options = { nx: nx, ex: ex }
    return false if nx && @entries.key?(key)

    @entries[key] = value
    "OK"
  end

  def get(key)
    @entries[key]
  end

  def del(key)
    @entries.delete(key) ? 1 : 0
  end
end

require_relative "../services/discourse_bale_notifications/link_code"

class LinkCodeTest < Minitest::Test
  def setup
    Discourse.redis = FakeRedis.new
  end

  def test_generates_six_digit_code_and_stores_user_id_with_ttl_and_nx
    code = DiscourseBaleNotifications::LinkCode.generate_for(Struct.new(:id).new(42))

    assert_match(/\A\d{6}\z/, code)
    assert_equal "42", Discourse.redis.get(DiscourseBaleNotifications::LinkCode.redis_key(code))
    assert_equal({ nx: true, ex: 900 }, Discourse.redis.last_set_options)
  end

  def test_consume_returns_user_id_and_deletes_code
    code = "012345"
    Discourse.redis.set(DiscourseBaleNotifications::LinkCode.redis_key(code), "73", nx: true, ex: 900)

    assert_equal 73, DiscourseBaleNotifications::LinkCode.consume(code)
    assert_nil Discourse.redis.get(DiscourseBaleNotifications::LinkCode.redis_key(code))
    assert_nil DiscourseBaleNotifications::LinkCode.consume(code)
  end

  def test_consume_rejects_blank_and_non_six_digit_inputs_without_redis_access
    redis = Discourse.redis
    assert_nil DiscourseBaleNotifications::LinkCode.consume(nil)
    assert_nil DiscourseBaleNotifications::LinkCode.consume("")
    assert_nil DiscourseBaleNotifications::LinkCode.consume("  ")
    assert_nil DiscourseBaleNotifications::LinkCode.consume("12345")
    assert_nil DiscourseBaleNotifications::LinkCode.consume("1234567")
    assert_nil DiscourseBaleNotifications::LinkCode.consume("12a456")
    assert_empty redis.entries
  end

  def test_generate_retries_when_candidate_already_exists
    service = DiscourseBaleNotifications::LinkCode
    values = ["111111", "222222"]
    original_random_number = SecureRandom.method(:random_number)
    calls = 0

    SecureRandom.define_singleton_method(:random_number) do |limit|
      raise "unexpected random limit" unless limit == 10**service::LENGTH

      value = values.fetch(calls)
      calls += 1
      value.to_i
    end

    Discourse.redis.set(service.redis_key("111111"), "99", nx: true, ex: service::TTL_SECONDS)
    code = service.generate_for(Struct.new(:id).new(42))

    assert_equal "222222", code
    assert_equal "99", Discourse.redis.get(service.redis_key("111111"))
    assert_equal "42", Discourse.redis.get(service.redis_key("222222"))
  ensure
    SecureRandom.define_singleton_method(:random_number, original_random_number) if original_random_number
  end
end
