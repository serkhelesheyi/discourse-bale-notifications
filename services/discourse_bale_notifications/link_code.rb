module DiscourseBaleNotifications
  # کدهای اتصال یک‌بارمصرف و کوتاه‌مدت برای اتصال امن حساب دیسکورس به چت بله.
  #
  # چرا این کلاس لازم است (فاز یک - اصلاح بحرانی/امنیتی #۸):
  # در طراحی قبلی، کاربر مقدار خام chat_id را که ربات در چت بله به او می‌داد،
  # مستقیماً و بدون هیچ تاییدیه‌ی برگشتی در پروفایل دیسکورس خود وارد می‌کرد.
  # chat_id یک شناسه‌ی پلتفرمی است، نه یک مقدار طراحی‌شده برای محرمانه ماندن؛
  # هر کسی که آن عدد را از هر طریقی بداند (حدس، اشتراک‌گذاری، مشاهده در یک
  # گروه مشترک) می‌توانست آن را در پروفایل *خودش* وارد کند و اعلان‌های
  # (از جمله پیام‌های خصوصی) کاربر دیگری را دریافت کند - بدون این‌که هرگز با
  # ربات صحبت کرده باشد یا کاربر واقعی رضایتی داده باشد.
  #
  # با این کلاس، فرآیند اتصال به یک تایید دوطرفه تبدیل می‌شود:
  #   ۱) کاربر باید وارد حساب دیسکورس خود شده باشد تا بتواند کد را دریافت کند.
  #   ۲) کاربر باید همان کد را از همان چت بله برای ربات ارسال کند.
  # فقط با برقراری هر دو شرط، اتصال برقرار می‌شود.
  class LinkCode
    TTL_SECONDS = 15 * 60
    LENGTH = 6
    MAX_GENERATION_ATTEMPTS = 10

    def self.redis_key(code)
      "discourse-bale-notifications:link-code:#{code}"
    end

    # یک کد عددی به طول LENGTH برای user می‌سازد، آن را حداکثر به‌مدت
    # TTL_SECONDS ثانیه در Redis نگه می‌دارد، و رشته‌ی کد را برمی‌گرداند.
    # از NX (فقط-در-صورت-نبودن) استفاده می‌شود تا در آن تصادف بسیار نادری که
    # همان کد قبلاً برای کاربر دیگری فعال است، به‌جای بازنویسی، دوباره تلاش شود.
    def self.generate_for(user)
      MAX_GENERATION_ATTEMPTS.times do
        candidate = SecureRandom.random_number(10**LENGTH).to_s.rjust(LENGTH, "0")
        created = Discourse.redis.set(redis_key(candidate), user.id.to_s, nx: true, ex: TTL_SECONDS)
        return candidate if created
      end

      raise "DiscourseBaleNotifications::LinkCode could not generate a unique code after #{MAX_GENERATION_ATTEMPTS} attempts"
    end

    # اگر ورودی یک کد معتبر و هنوز منقضی‌نشده باشد، user_id مربوطه را
    # برمی‌گرداند و بلافاصله کد را باطل می‌کند (یک‌بارمصرف بودن). در غیر
    # این‌صورت nil برمی‌گرداند و هیچ تغییری در Redis ایجاد نمی‌شود.
    def self.consume(code)
      return nil if code.blank?

      # فقط رشته‌های عددی دقیقاً به طول LENGTH به‌عنوان کد در نظر گرفته
      # می‌شوند، تا برای هر پیام دلخواه کاربران (که معمولاً کد نیستند) درخواست
      # غیرضروری به Redis زده نشود.
      return nil unless code.match?(/\A\d{#{LENGTH}}\z/)

      key = redis_key(code)
      user_id = Discourse.redis.get(key)
      return nil if user_id.nil?

      Discourse.redis.del(key)
      user_id.to_i
    end
  end
end
