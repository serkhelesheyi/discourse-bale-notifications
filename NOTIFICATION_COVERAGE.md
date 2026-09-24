# پوشش انواع اعلان دیسکورس در discourse-bale-notifications

این سند دقیقاً مشخص می‌کند این افزونه کدام انواع اعلان دیسکورس را واقعاً
می‌تواند به بله ارسال کند، کدام‌ها را نه، و **چرا** - بر مبنای بررسی مستقیم
سورس فعلی `app/services/post_alerter.rb` در هسته‌ی دیسکورس، نه حدس یا فرض.

## مکانیزم زیربنایی

این افزونه به رویداد `DiscourseEvent :push_notification` گوش می‌دهد. این
رویداد **فقط و فقط** از داخل متد `PostAlerter#create_notification_alert`
فراخوانی می‌شود؛ و آن متد هم، به‌نوبه‌ی خود، **فقط از داخل** `create_notification`
و **فقط وقتی** نوع اعلان درون ثابت زیر باشد صدا زده می‌شود:

```ruby
# app/services/post_alerter.rb (هسته‌ی دیسکورس)
NOTIFIABLE_TYPES = [
  :mentioned, :replied, :quoted, :posted, :linked,
  :private_message, :group_mentioned, :watching_first_post
].map { |t| Notification.types[t] }
```

به‌عبارت دیگر: **هر نوع اعلانی که خارج از این ۸ مورد باشد، مهم نیست چه
تنظیماتی در این افزونه فعال باشد یا چه ترجمه‌ای نوشته شود - هرگز به این
رویداد نمی‌رسد و هرگز ارسال نخواهد شد.** این یک محدودیت معماری در سطح خودِ
دیسکورس است، نه یک باگ در این افزونه.

## جدول پوشش

### ✅ پشتیبانی‌شده و تاییدشده (بخشی از NOTIFIABLE_TYPES هسته)
این ۸ مورد مستقیماً از سورس هسته تایید شده‌اند و همگی از پیش در
`bale_enabled_notification_types` فعال هستند:

| نوع | فایل ترجمه | وضعیت |
|---|---|---|
| `mentioned` | ✅ موجود | تایید شده |
| `replied` | ✅ موجود | تایید شده |
| `quoted` | ✅ موجود | تایید شده |
| `posted` | ✅ موجود | تایید شده |
| `linked` | ✅ موجود | تایید شده |
| `private_message` | ✅ موجود | تایید شده |
| `group_mentioned` | ✅ موجود | تایید شده |
| `watching_first_post` | ✅ موجود | تایید شده |

### ⚠️ وابسته به افزونه‌ی دیگر - محتمل ولی تاییدنشده
این موارد از افزونه‌های جانبی می‌آیند که ممکن است `create_notification_alert`
را مستقیماً و مستقل از `NOTIFIABLE_TYPES` هسته صدا بزنند (همان‌طور که ظاهراً
افزونه‌ی discourse-follow برای دو مورد اول انجام می‌دهد). **این دو مورد در این
بررسی به‌صورت قطعی تایید نشدند** و نیاز به تست عملی روی یک نصب واقعی با
افزونه‌ی مربوطه دارند:

| نوع | منبع | وضعیت |
|---|---|---|
| `following_replied` | افزونه discourse-follow | محتمل (از پیش در کد اصلی افزونه فرض شده بود) |
| `following_posted` | افزونه discourse-follow | محتمل (از پیش در کد اصلی افزونه فرض شده بود) |
| `event_reminder` | افزونه discourse-calendar | **تاییدنشده** - ترجمه در فاز دو اضافه شد، اما مشخص نیست این رویداد اصلاً fire می‌شود یا خیر |
| `event_invitation` | افزونه discourse-calendar | **تاییدنشده** - همانند بالا |

**توصیه:** اگر discourse-calendar روی سایت شما نصب است، یک رویداد واقعی
(یادآوری/دعوت) برای یک کاربر تست‌شده ایجاد کنید و بررسی کنید آیا پیام بله
واقعاً دریافت می‌شود. اگر دریافت نشد، این دو مورد را از
`bale_enabled_notification_types` حذف کنید تا در تنظیمات سایت گزینه‌ای
بی‌اثر و گمراه‌کننده نماند.

### ❌ پشتیبانی‌نشده - از نظر معماری غیرممکن (بدون تغییرات ساختاری بزرگ‌تر)
این موارد **هرگز** از طریق `push_notification` قابل‌دریافت نیستند، چون یا
صراحتاً از `NOTIFIABLE_TYPES` هسته کنار گذاشته شده‌اند، یا اصلاً از مسیر
`PostAlerter#create_notification` عبور نمی‌کنند:

| نوع | چرا غیرممکن است |
|---|---|
| `liked` | صراحتاً از `NOTIFIABLE_TYPES` هسته کنار گذاشته شده (تایید مستقیم از سورس) |
| `liked_consolidated` | همانند بالا؛ علاوه‌براین از طریق `Notification.create!` مستقیم ساخته می‌شود، نه `create_notification` |
| `edited` | صراحتاً از `NOTIFIABLE_TYPES` هسته کنار گذاشته شده (تایید مستقیم از سورس) |
| `group_message_summary` | از طریق `Notification.create` مستقیم در `notify_group_summary` ساخته می‌شود، نه `create_notification_alert` |
| `granted_badge` | توسط `BadgeGranter` مستقیماً و کاملاً مستقل از `PostAlerter` ساخته می‌شود |
| `moved_post` | توسط `PostMover`/`TopicMover` ساخته می‌شود، نه `PostAlerter#create_notification` |
| `invited_to_topic`, `invited_to_private_message`, `invitee_accepted` | از جریان دعوت‌نامه (`Invite`) می‌آیند، نه از `PostAlerter` |
| `bookmark_reminder` | توسط جاب زمان‌بندی‌شده‌ی یادآوری بوکمارک ساخته می‌شود |
| `custom` | یک نوع عمومی که افزونه‌های دیگر (مثل discourse-solved) مستقیماً با `Notification.create!` می‌سازند |
| `post_approved`, `membership_request_accepted`, `membership_request_consolidated`, `votes_released` | هرکدام از جریان‌های اختصاصی خودشان می‌آیند، نه `PostAlerter` |
| `chat_mention`, `chat_message`, `chat_invitation` و سایر انواع چت | افزونه‌ی Discourse Chat یک سیستم اعلان کاملاً مجزا و مستقل از `PostAlerter` دارد |

## اگر پوشش بیشتری لازم است

تنها راه واقعی برای پوشش کامل‌تر، **تغییر نقطه‌ی اتصال** است: به‌جای گوش دادن
به رویداد `push_notification` (که محدود به ۸ نوع بالاست)، می‌توان یک
`after_create` callback مستقیماً روی مدل `Notification` ثبت کرد که برای
**هر** نوع اعلانی fire می‌شود، صرف‌نظر از این‌که از کدام مسیر ساخته شده. این
یک تغییر معماری معنادار است (نیازمند بررسی کارایی/تکرار پیام‌ها، چون برخی
انواع - مثل `liked_consolidated` - به‌صورت batched/updated هم ساخته می‌شوند
نه فقط created) و در نقشه‌راه به‌عنوان یک گزینه‌ی فاز آینده مطرح می‌شود، نه
بخشی از این تحویل.
