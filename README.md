# افزونهٔ اعلان‌های دیسکورس در پیام‌رسان بله

این افزونه بخشی از اعلان‌های انجمن [Discourse](https://www.discourse.org/) را به چت خصوصی ربات [بله](https://ble.ir/) می‌فرستد. بسته به نسخه و تنظیمات، کاربر می‌تواند از پیام اعلان به پست انجمن برود، پست را لایک/آنلایک کند یا به آن پاسخ بدهد.

> **وضعیت:** مخزن در حال ممیزی و بهبود مرحله‌ای است. نقشه‌راه و وضعیت آزمون‌ها را در [ROADMAP.md](ROADMAP.md) و محدودیت انواع اعلان را در [NOTIFICATION_COVERAGE.md](NOTIFICATION_COVERAGE.md) ببینید. وجود یک گزینه یا ترجمه به‌تنهایی تضمین نمی‌کند که رویداد آن در نسخهٔ جاری Discourse تولید شود.


> **وضعیت عملیاتی و ممیزی، ۱۸ اکتبر ۲۰۲۶:** PR شمارهٔ [۲](https://github.com/serkhelesheyi/discourse-bale-notifications/pull/2) با موفقیت ادغام شد؛ commit ادغام `df5089736b51f7f696efad1333b32272188c4142` است. CI کامل و smoke tests روی HEAD شاخهٔ تشخیصی موفق بودند. این ادغام فقط ابزار عیب‌یابی اختیاری را به مخزن اضافه کرده است و به‌معنای نصب یا استقرار آن روی سرور نیست. طبق آخرین وضعیت ثبت‌شده، نسخهٔ تولیدی قبلی روی SHA `b75d69a190184b5c62aae4fba2364e2c8f79eb0b` بوده؛ وضعیت سرور هنوز باید مستقلاً بررسی شود. گام بعدی: به‌روزرسانی کنترل‌شدهٔ افزونه از پنل مدیریت، فعال‌سازی کوتاه‌مدت تنظیم تشخیصی، ثبت دو نمونهٔ ریپلای و خاموش‌کردن فوری تنظیم. علت ریشه‌ای هنوز اثبات نشده است.

## قابلیت‌ها

- ارسال انواع اعلان پشتیبانی‌شده به چت خصوصی بله.
- اتصال حساب با کد یک‌بارمصرف شش‌رقمی با اعتبار ۱۵ دقیقه.
- قطع اتصال از تنظیمات کاربری.
- ترجیحات شخصی برای انتخاب انواع اعلان مجازشده توسط مدیر سایت.
- دکمه‌های مشاهدهٔ پست و تعامل‌هایی مانند لایک/آنلایک و پاسخ، در موارد پشتیبانی‌شده.
- ابزارهای مدیریتی و تشخیصی موجود در نسخهٔ جاری.
- ارسال اختیاری آواتار و تحویل بی‌صدا در ساعات سکوت.

## پیش‌نیازها

- نصب فعال Discourse با امکان نصب افزونهٔ سفارشی.
- دسترسی مدیریتی به تنظیمات سایت و بازسازی کانتینر در صورت نیاز.
- ربات بله و access token معتبر.
- دسترسی خروجی سرور به API بله از طریق HTTPS و دامنهٔ عمومی برای webhook.

نسخه‌های دقیق Discourse و API بله که رسماً پشتیبانی و آزموده شده‌اند باید پس از تکمیل خط مبنا در [ROADMAP.md](ROADMAP.md) ثبت شوند؛ در حال حاضر ادعای سازگاری تأییدشده با همهٔ نسخه‌ها نداریم.

## نصب

۱. افزونه را طبق راهنمای رسمی [نصب افزونهٔ Discourse](https://meta.discourse.org/t/install-a-plugin/19157) به نصب خود اضافه کنید.

۲. در نصب‌های مبتنی بر `containers/app.yml`، مخزن افزونه را با روش رسمی همان نصب در بخش `hooks/after_code/exec` معرفی کنید. پیش از ویرایش، از فایل پیکربندی نسخهٔ پشتیبان بگیرید و مسیرها و دستورها را با ساختار واقعی نصب تطبیق دهید.

۳. کانتینر را طبق فرایند نگهداری معمول خود بازسازی کنید و سپس تنظیمات افزونه را در تنظیمات سایت بررسی کنید.

## پیکربندی اولیه

۱. با [BotFather بله](https://ble.ir/botfather) ربات بسازید و access token را در تنظیمات سایت قرار دهید.
۲. گزینهٔ فعال‌سازی اعلان‌های بله را روشن کنید.
۳. انواع اعلان مورد نیاز را انتخاب کنید. بعضی انواع به افزونه‌های دیگر یا رویدادهای خاص وابسته‌اند؛ [NOTIFICATION_COVERAGE.md](NOTIFICATION_COVERAGE.md) را بخوانید.
۴. در صورت وجود پنل مدیریتی در نسخهٔ نصب‌شده، وضعیت webhook و پیام آزمایشی را بررسی کنید.
۵. استفادهٔ ربات در گروه‌ها را غیرفعال کنید (از جمله `/setjoingroups` در صورت پشتیبانی). این توصیه جایگزین بررسی مجوزها و رفتار خود افزونه نیست.

**هرگز** access token، secret وب‌هوک یا URL حاوی secret را در Git، issue عمومی، تصویر صفحه یا لاگ قابل اشتراک منتشر نکنید.

## اتصال حساب کاربر

۱. وارد حساب Discourse شوید و تنظیمات کاربری را باز کنید.
۲. بخش **Bale Notifications** را پیدا کنید و کد اتصال بگیرید.
۳. کد شش‌رقمی را در مدت ۱۵ دقیقه به‌صورت پیام خصوصی برای ربات بله بفرستید.
۴. پیام تأیید را دریافت کنید؛ سپس اتصال برقرار است.
۵. برای قطع اتصال، از همان بخش تنظیمات کاربری گزینهٔ قطع اتصال را بزنید.

کد اتصال را در فضای عمومی یا برای شخص دیگری نفرستید. اگر کد منقضی شد یا قبلاً مصرف شد، کد تازه‌ای بگیرید.

## تنظیمات اختیاری

- **انواع اعلان شخصی:** کاربر از میان انواع فعال‌شده در سطح سایت، زیرمجموعهٔ دلخواه خود را انتخاب می‌کند.
- **آواتار:** در صورت فعال‌بودن، آواتار کاربر عامل ممکن است همراه کپشن ارسال شود. اگر متن از حد کپشن بیشتر باشد، مسیر متنی جایگزین می‌شود.
- **ساعات سکوت:** در بازهٔ تنظیم‌شده، پیام حذف یا به تعویق نمی‌افتد؛ از API بله درخواست تحویل بی‌صدا می‌شود. در صورت وجود منطقهٔ زمانی معتبر کاربر، همان منطقه مبناست.

## حریم خصوصی و امنیت

اعلان‌ها ممکن است حاوی محتوای خصوصی انجمن باشند؛ از ربات و توکنی استفاده کنید که تحت کنترل شماست. کد اتصال کوتاه‌عمر برای جلوگیری از اتصال صرفاً بر اساس دانستن Chat ID طراحی شده است. دسترسی به پنل مدیریتی و پیام آزمایشی باید به مدیران مجاز محدود بماند. پیام گروه/کانال نباید به‌عنوان چت خصوصی تلقی شود.

این بخش توصیف اهداف و رفتار طراحی‌شده است، نه گواهی امنیتی مستقل؛ موارد امنیتی و آزمون‌های رگرسیون در [ROADMAP.md](ROADMAP.md) پیگیری می‌شوند.

## عیب‌یابی

### اعلان نمی‌رسد
- فعال‌بودن افزونه و اعتبار توکن را بررسی کنید.
- اتصال کاربر و ترجیحات شخصی را بررسی کنید.
- مطمئن شوید نوع اعلان در سطح سایت فعال است و در نسخهٔ جاری Discourse واقعاً از مسیر پشتیبانی‌شده تولید می‌شود.
- jobهای ناموفق و لاگ‌های Discourse را بررسی کنید؛ پیش از اشتراک‌گذاری، اطلاعات محرمانه را حذف کنید.

### اتصال انجام نمی‌شود
- کد را در چت خصوصی ربات صحیح بفرستید.
- بررسی کنید کد منقضی یا قبلاً مصرف نشده باشد.
- از تنظیمات کاربری یک کد جدید بسازید.

### وب‌هوک کار نمی‌کند
- دسترسی عمومی HTTPS به دامنهٔ انجمن و دسترسی خروجی سرور به API بله را بررسی کنید.
- توکن و وضعیت webhook را از ابزارهای مدیریتی/لاگ محلی بررسی کنید.
- secret را در گزارش عمومی درج نکنید.

### گزینه‌ای هست ولی اعلانش نمی‌رسد
وجود ترجمه یا گزینه اثبات نمی‌کند که هسته یا افزونهٔ جانبی آن رویداد را تولید می‌کند. [NOTIFICATION_COVERAGE.md](NOTIFICATION_COVERAGE.md) را بررسی و رفتار را با حساب آزمایشی در محیط staging امتحان کنید.

## توسعه و آزمون

- نقشه‌راه، یافته‌های ممیزی، معیارهای خروج، اختلاف شاخه‌ها و سوابق CI در [ROADMAP.md](ROADMAP.md) ثبت می‌شوند.
- CI اصلی افزونه از workflow رسمی Discourse استفاده می‌کند: [`.github/workflows/discourse-plugin.yml`](.github/workflows/discourse-plugin.yml). این workflow lint و آزمون‌های backend/RSpec را اجرا می‌کند.
- آزمون‌های سبک مستقل در [`.github/workflows/plugin-smoke-tests.yml`](.github/workflows/plugin-smoke-tests.yml) اجرا می‌شوند و شامل syntax check و `test/link_code_test.rb` هستند. این workflow اکنون برای `main` و شاخهٔ ممیزی فعال است.
- آزمون‌های RSpec شامل مصرف اتمیک کد اتصال، escape کردن HTML، ورودی‌های وب‌هوک و API client هستند. آزمون API client مسیر موفق، HTTPS و timeout، timeout شبکه، پاسخ غیر JSON، JSON با ساختار نامعتبر، خطای API و عدم افشای توکن/متن پیام خروجی در لاگ‌های سناریوهای پوشش‌داده‌شده را بررسی می‌کند.
- پاسخ JSON که شیء نباشد، از جمله `null`، به‌صورت شکست کنترل‌شده رد می‌شود. قالب دقیق متن داخلی استثنا در آزمون timeout معیار نیست؛ نوع خطا و نتیجهٔ امن آن بررسی می‌شود.
- وضعیت CI روی HEAD ثبت‌شده در ۱۷ اکتبر ۲۰۲۶: [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38820273999) و [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38820273684) هر دو موفق بوده‌اند. این نتایج فقط SHA مربوط به همان اجرا را پوشش می‌دهند؛ پس از تغییر مستندات، نتیجهٔ HEAD جدید باید دوباره بررسی شود. وضعیت جاری در [Actions](https://github.com/serkhelesheyi/discourse-bale-notifications/actions) قابل مشاهده است.
- تغییرات شاخهٔ ممیزی از طریق PR شمارهٔ [#1](https://github.com/serkhelesheyi/discourse-bale-notifications/pull/1) ادغام شده‌اند. تاریخچهٔ قدیمی‌تر این README ممکن است وضعیت‌های پیش از ادغام را توصیف کند؛ برای وضعیت جاری، انتهای [ROADMAP.md](ROADMAP.md) مرجع است.
- این آزمون‌ها جایگزین آزمون پذیرش روی staging، بررسی قرارداد واقعی API بله یا تأیید سازگاری با همهٔ نسخه‌های Discourse نیستند.

## حذف افزونه

پیش از حذف، اعلان‌ها را در تنظیمات سایت غیرفعال و وضعیت webhook را بررسی کنید. سپس افزونه را از پیکربندی نصب حذف و کانتینر را طبق روش معمول بازسازی کنید. اگر پاک‌سازی اتصال کاربران یا داده‌های ذخیره‌شده لازم است، ابتدا روش نسخهٔ جاری و نسخهٔ پشتیبان را بررسی کنید؛ پایگاه داده را دستی و بدون بررسی پاک‌سازی نکنید.

## گزارش باگ و مشارکت

گزارش باگ باید شامل نسخهٔ Discourse، commit افزونه، مراحل بازتولید، نتیجهٔ مورد انتظار و نتیجهٔ واقعی باشد. توکن، secret، متن پیام خصوصی و شناسه‌های شخصی را حذف کنید. اصلاحات باید محدود، قابل توضیح و همراه آزمون متناسب با ریسک باشند.


## وضعیت ممیزی فنی (۱۵ اکتبر ۲۰۲۶)

- وب‌هوک اکنون payloadهای ناقص یا غیرخصوصی را پیش از دسترسی به فیلدهای تو‌در‌تو رد/تأیید می‌کند و برای خطاهای احراز هویت پاسخ JSON مشخص می‌دهد.
- آزمون‌های request مسیر موفق لایک/آنلایک و پاسخ به اعلان ذخیره‌شده افزوده شده‌اند؛ این‌ها وضعیت پایگاه داده و فراخوانی‌های خروجی mock‌شده را بررسی می‌کنند و تا سبزشدن CI روی HEAD جاری تأیید نهایی نیستند.
- URLهای تزریق‌شده به قالب‌های HTML اعلان، از جمله پیوند کاربر، پیوند پست و پیوند پاسخ موفق، پیش از interpolation با HTML escape می‌شوند؛ متن پویا مانند عنوان، نام کاربر و excerpt نیز escape می‌شود.
- اجرای CI شمارهٔ [38707675576](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38707675576) ناموفق بود: ۲ شکست از ۱۲ مثال RSpec و شکست RuboCop. دو شکست به انتظارات mock در آزمون callback مربوط بودند و اصلاح شده‌اند؛ اجرای تأییدی پس از اصلاح هنوز لازم است.
- RuboCop در اجرای یادشده ۳۵۲ تخلف در ۷ فایل گزارش کرد که بخش قابل توجهی از آن‌ها از کد قدیمی و گسترده‌تر از تغییرات این مرحله است. این موارد نباید با موفقیت lint اشتباه گرفته شوند؛ پاک‌سازی سراسری lint باید جداگانه و کنترل‌شده انجام شود.
- وضعیت فعلی تغییرات و نتیجهٔ اجرای تازهٔ CI را در [ROADMAP.md](ROADMAP.md) دنبال کنید. این شاخه هنوز ادغام یا مستقر نشده است.


### پیگیری جدید Lint — ۱۵ اکتبر ۲۰۲۶

اجرای CI شمارهٔ [38709178682](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38709178682) نشان داد backend tests موفق شده‌اند، اما lint همچنان ناموفق است: RuboCop در ۷ فایل **۳۱۷ تخلف** گزارش کرد که **۲۳۲ مورد قابل اصلاح خودکار** بودند. این عدد مربوط به همان commit آزموده‌شده است؛ پس از آن چند اصلاح محدود در Gemfile، آزمون webhook و rescue ثبت فعالیت انجام شده و اجرای تأییدی آن‌ها هنوز باید بررسی شود.

اصلاحات محدود انجام‌شده:
- رشته‌های Gemfile با سبک تک‌نقل‌قول هماهنگ شدند.
- trailing comma نامعتبر در دو آزمون callback حذف شد.
- rescue ثبت لاگ به StandardError محدود شد.
- اعتبارسنجی payload به helper مشترک valid_private_chat? منتقل شد تا پیچیدگی غیرضروری کاهش یابد.

این اصلاحات، ادعای رفع تمام تخلفات Lint نیستند. پاک‌سازی کامل هنوز باز است و هیچ استثنای سراسری برای خاموش‌کردن RuboCop اضافه نشده است.


## وضعیت ممیزی lint (۱۵ اکتبر ۲۰۲۶)

در شاخه `docs/initial-audit-roadmap` اصلاح مکانیکی و محافظه‌کارانهٔ رشته‌های سادهٔ بدون interpolation، escape یا نقل‌قول تکی و فاصله‌های انتهای خطوط آغاز شده است. نتیجهٔ نهایی فقط پس از اجرای دوبارهٔ RuboCop و تست‌های CI معتبر است؛ این مرحله به‌تنهایی به معنای سبزشدن lint نیست.


### نتیجهٔ اجرای CI پس از پاک‌سازی اولیه — ۱۵ اکتبر ۲۰۲۶

اجرای [38713002053](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38713002053) همچنان ناموفق بود: RuboCop تعداد **۱۶۷ تخلف** (۸۵ مورد قابل اصلاح خودکار) گزارش کرد و RSpec به‌علت ناهماهنگی انتظار آزمون `escape_html` با خروجی واقعی `CGI.escapeHTML` شکست خورد. این شاخه هنوز آمادهٔ ادغام نیست. اصلاح انتظار آزمون و چند مورد سبک مستقل در commit بعدی انجام می‌شود؛ پس از آن CI باید دوباره اجرا و نتیجهٔ کامل بررسی شود.


### نتیجهٔ CI برای commit 0101be7 — ۱۵ اکتبر ۲۰۲۶

اجرای [38713600491](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38713600491) کامل شده است: backend tests و Syntax Tree موفق‌اند، اما RuboCop ناموفق است و **۱۶۶ تخلف** در سه فایل گزارش می‌کند: `plugin.rb` (۷۱)، `bale-notifier.rb` (۹۳) و `link_code.rb` (۲). بنابراین شاخه هنوز آمادهٔ ادغام نیست. در این مرحله دو اصلاح صرفاً سبکی و بدون تغییر رفتار در `link_code.rb` انجام می‌شود؛ پس از اجرای CI بعدی، تعداد جدید باید از لاگ واقعی ثبت شود.


### پیگیری CI: commit `cd48fcc` — ۱۵ اکتبر ۲۰۲۶

اجرای [38714371226](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38714371226) کامل شد: `check_for_tests` و `backend_tests` موفق، اما `linting` ناموفق است. RuboCop همچنان **۱۶۶ تخلف** در ۷ فایل گزارش می‌کند؛ ۸۵ مورد قابل اصلاح خودکارند. بررسی لاگ نشان داد اصلاح قبلی `link_code.rb` به‌اشتباه رشتهٔ دارای interpolation را به کوتیشن تکی تبدیل کرده بود؛ این خطا اکنون با کوتیشن دوتایی اصلاح می‌شود. نام‌گذاری camelCase در `bale-notifier.rb` و تخلفات ساختاری `plugin.rb` هنوز باز هستند.


### پیگیری اصلاح دسته‌ای RuboCop — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38715094520](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38715094520) روی commit `0a335291f52cbb57872c183937d2067148c95f6f` کامل شد: `check_for_tests` و `backend_tests` موفق، اما `linting` ناموفق بود. RuboCop تعداد **۱۶۵ تخلف در ۷ فایل** (۸۴ مورد قابل اصلاح خودکار) گزارش کرد؛ تفکیک فایل‌ها: `plugin.rb` = ۷۱، `bale-notifier.rb` = ۹۳، `link_code.rb` = ۱.

#### دستهٔ اول: نام‌گذاری متغیرها و اصلاح‌های محلیِ بدون تغییر قرارداد

در `bale-notifier.rb` نام متغیرهای محلی/پارامترهای `responseData`، `methodName`، `likeButtonText` و `likeButtonAction` به صورت `snake_case` تغییر داده شد. همچنین شرط منفی به `unless`، بازگشت نهایی زائد حذف، بررسی شمارنده‌ها به `.positive?` و شرط ثبت لاگ به guard clause تبدیل شد. در `link_code.rb` نیز بخش ثابت رشتهٔ خطا به کوتیشن تکی تغییر کرد و بخش دارای interpolation همچنان دابل‌کوتیشن باقی ماند.

این دسته فقط تغییرهای محدود و قابل ردیابی را شامل می‌شود؛ نام متدهای عمومی camelCase و رشته‌های نام متدهای API بله عمداً هنوز تغییر نکرده‌اند تا فراخوان‌ها و قراردادها در یک مرحلهٔ مستقل بررسی شوند. این commit هنوز باید با CI تأیید شود؛ تعداد تخلف‌های باقی‌مانده تا دریافت گزارش جدید نامعلوم است.


### پیگیری دستهٔ دوم اصلاح lint — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38715889729](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38715889729) روی commit `b089cc1` کامل شد: آزمون‌های backend و شناسایی آزمون‌ها موفق، lint ناموفق. RuboCop تعداد **۱۲۲ تخلف در ۷ فایل** (۷۶ مورد قابل اصلاح خودکار) گزارش کرد؛ نسبت به اجرای قبلی با ۱۶۵ تخلف، ۴۳ مورد کمتر. دستهٔ دوم فقط اصلاح‌های مکانیکی و روشن در `plugin.rb` را شامل می‌شود: کوتیشن رشته‌های ثابت، حذف freeze زائد از رشتهٔ ثابت، و حذف کاماهای پایانی در hashها. ساختار کنترلرها، نام متدها و منطق اجرایی در این دسته دست‌نخورده می‌ماند. نتیجهٔ CI این دسته باید پیش از ادامه ثبت شود.


### دستهٔ سوم: اصلاح‌های مکانیکی تکمیلی — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38717317643](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38717317643) کامل شد: `backend_tests` و `check_for_tests` موفق، `linting` ناموفق. شمار تخلف‌های RuboCop به **۱۱۰ در ۷ فایل** (۶۴ مورد قابل اصلاح خودکار) کاهش یافت؛ نسبت به ۱۲۲ مورد اجرای پیشین، ۱۲ تخلف کمتر. دستهٔ سوم شامل اصلاح فراخوانی‌های `CGI.escapeHTML`، نام‌گذاری پارامترهای استفاده‌نشده، guard clause، کوتیشن‌های frozen string و چند سبک محلی در notifier است. هیچ نام متد عمومی یا رشتهٔ API بله در این دسته تغییر نکرده است. موارد ساختاری و پیچیدگی متدها هنوز باز هستند.


### دستهٔ چهارم: نام‌گذاری متدهای داخلی و مسیر فایل — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38717927736](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38717927736) کامل شد: آزمون‌های backend و شناسایی آزمون‌ها موفق، lint ناموفق. تخلفات RuboCop از ۱۱۰ به **۷۸ در ۷ فایل** کاهش یافت (۳۲ مورد کمتر؛ ۳۳ مورد قابل اصلاح خودکار). در این دسته نام متدهای Ruby داخلی در notifier به `snake_case` تغییر می‌کند و فراخوان‌های شناخته‌شده در `plugin.rb` و آزمون وب‌هوک به‌روز می‌شوند؛ رشته‌های متدهای HTTP بله مانند `sendMessage` و `answerCallbackQuery` عمداً دست‌نخورده‌اند. نام فایل notifier نیز به `bale_notifier.rb` تغییر می‌کند و مسیر autoload متناسب با آن اصلاح می‌شود. CI این دسته باید صحت تغییرها را تأیید کند.


### دستهٔ پنجم: پیگیری پس از تغییر نام متدها — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38718294482](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38718294482) کامل شد: `backend_tests` و `check_for_tests` موفق، lint ناموفق؛ RuboCop تعداد **۶۳ تخلف در ۷ فایل** (۲۸ مورد قابل اصلاح خودکار) گزارش کرد، ۱۵ مورد کمتر از اجرای قبلی. بازبینی گزارش علاوه بر سبک، یک نکتهٔ سازگاری Ruby 3 را آشکار کرد: هنگام تغییر قالب hash در فراخوانی‌های notifier باید hash صریحاً به‌عنوان آرگومان positional حفظ شود. این دسته آن را حفظ می‌کند، نام `get_webhook_info` را به `fetch_webhook_info` اصلاح می‌کند و چند تخلف مکانیکی باقی‌مانده را برطرف می‌سازد. آزمون CI جدید باید این تغییرها را تأیید کند.


### دستهٔ ششم: جداسازی مسئولیت‌های notifier — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38718782222](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38718782222) کامل شد: `backend_tests` و `check_for_tests` موفق، lint ناموفق؛ گزارش RuboCop **۵۴ تخلف در ۷ فایل** (۱۹ مورد قابل اصلاح خودکار) نشان داد. این دسته مسئولیت ثبت تاریخچهٔ فعالیت و ساخت دکمه‌های پاسخ را از `BaleNotifier` جدا می‌کند تا کلاس ارسال API کوچک‌تر و قابل آزمون‌تر شود. فایل‌های `bale_activity_log.rb` و `bale_reply_markup.rb` اضافه شده‌اند و autoload مربوطه ثبت می‌شود. این تغییر ساختاری است؛ CI جدید باید پیش از ادامه، بارگذاری کلاس‌ها و آزمون‌ها را تأیید کند.


### دستهٔ هفتم: تفکیک API client و کوچک‌سازی متدها — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38719535054](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38719535054) گزارش **۵۷ تخلف در ۹ فایل** (۲۲ مورد قابل اصلاح خودکار) داد؛ آزمون‌های backend و شناسایی تست‌ها موفق بودند. در این دسته، پیاده‌سازی HTTP و مدیریت خطا به `BaleApiClient` منتقل شده، ساخت payload پیام از متد اصلی ارسال جدا شده، و ساخت دکمه و ثبت لاگ به توابع کوچک‌تر تفکیک شده است. هدف حذف تخلف‌های پیچیدگی از راه اصلاح ساختار واقعی است، نه خاموش‌کردن RuboCop. نتیجهٔ CI جدید باید این بازآرایی را تأیید کند.


### دستهٔ هشتم: کوچک‌سازی API client و payload builder — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38720093308](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38720093308) کامل شد: آزمون‌های backend و شناسایی تست‌ها موفق؛ RuboCop **۴۵ تخلف در ۱۰ فایل** (۱۴ مورد قابل اصلاح خودکار) گزارش کرد. این دسته منطق HTTP را به چند مرحلهٔ مشخص (ساخت درخواست، ارسال، parse پاسخ و مدیریت خطا) تقسیم می‌کند و ساخت payload پیام را از notifier جدا می‌سازد. رفتار خطاهای شبکه، پاسخ غیر JSON، خطاهای API و ثبت فعالیت باید در CI تأیید شود.


### دستهٔ نهم: جداسازی کنترلرها و jobها از initializer — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38720688542](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38720688542) کامل شد: `backend_tests` و `check_for_tests` موفق؛ RuboCop **۳۴ تخلف در ۱۱ فایل** (۶ مورد قابل اصلاح خودکار) گزارش کرد. این دسته سه کنترلر (`BaleController`، `LinkController`، `AdminController`) و دو job را از `plugin.rb` به فایل‌های جدا منتقل می‌کند و با autoload صریح ثبت می‌کند. هدف کاهش طول initializer و حذف هشدارهای تعریف کلاس داخل block، بدون تغییر مسیرها یا منطق endpointهاست. آزمون‌های Zeitwerk و backend باید این انتقال را تأیید کنند.


### دستهٔ دهم: اصلاح خطاهای قطعی CI و مسیر بارگذاری — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38725027999](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38725027999) کامل شد و شکست خورد: `check_for_tests` موفق بود، اما `linting` با **۱۳ تخلف در ۱۹ فایل** و `backend_tests` در `zeitwerk:check` شکست خورد. خطای بارگذاری به پیدا نشدن `DiscourseBaleNotifications::PluginSetup` مربوط بود؛ همچنین i18n lint دو مقدار ترجمه را به‌علت عبارت ممنوع «private message» رد کرد.

در commit اصلاحی بعدی، مسیر autoload به‌صورت plugin-relative و در سطح ماژول تعریف می‌شود تا بارگذاری `PluginSetup` به `require_dependency` داخل callback وابسته نباشد. متن نمایشی ترجمه از «Private messages» به «Personal messages» تغییر می‌کند، اما کلید فنی `private_message` حفظ می‌شود. اصلاح‌های سبک کم‌خطر نیز محدود به حذف `begin` زائد، `return` زائد و خط خالی اضافی است. این تغییرها هنوز منتظر اجرای CI هستند و نباید رفع‌شده تلقی شوند.


### دستهٔ یازدهم: کاهش پنج تخلف باقی‌ماندهٔ RuboCop

اجرای [CI شمارهٔ 38746914696](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38746914696) روی commit `153a78b` گزارش داد که تخلف‌های RuboCop از ۱۳ به **۵** کاهش یافته‌اند. سه تخلف به طول/پیچیدگی متدها در کنترلر وب‌هوک و دو تخلف به متدهای `authenticate_webhook_request`، `unlike_action_text` و `handle_message` مربوط بود. در این دسته فقط منطق موجود به متدهای کوچک‌تر استخراج می‌شود؛ محدودیت نرخ، پاسخ‌های HTTP، متن‌های ترجمه، ترتیب عملیات و payload ارسالی حفظ شده‌اند.

این تغییر هنوز تأیید CI ندارد؛ اجرای کامل آزمون backend مربوط به دستهٔ قبلی در زمان ثبت این یادداشت در جریان بود. نتیجهٔ نهایی باید با اجرای تازهٔ CI بررسی شود.


### دستهٔ دوازدهم: حفظ ترتیب مقداردهی Rails Engine

در اجرای [CI شمارهٔ 38747318499](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38747318499)، RuboCop موفق شد؛ اما مرحلهٔ `Check Zeitwerk eager_load` با خطای واقعی `No such middleware to insert before: Rails::Rack::Logger` شکست خورد. این خطا با تشخیص قبلیِ پیدا نشدن `PluginSetup` متفاوت است. بررسی diff نشان می‌دهد تعریف Rails Engine از `after_initialize` به سطح بارگذاری فایل منتقل شده بود و ترتیب ایجاد Engine نسبت به middlewareهای برنامه تغییر کرده بود. اصلاح بعدی ساخت Engine را به callback برمی‌گرداند، بدون تعریف کلاس/ماژول مستقیم درون بلوک و بدون دست‌کاری middleware هسته. این راهکار تا تأیید اجرای CI صرفاً یک اصلاح آزمایشی مبتنی بر خطای ثبت‌شده است.

### دستهٔ سیزدهم: بررسی خطای namespace در Zeitwerk — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38747805691](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38747805691) کامل شد و هر دو مرحلهٔ `linting` و `backend_tests` شکست خوردند. گزارش lint دقیقاً یک تخلف مکانیکی در `plugin.rb:40` (خط خالی اضافی) داشت. آزمون eager-load خطای `uninitialized constant #<Class...>::DiscourseBaleNotifications::PluginSetup` را گزارش کرد؛ این خطا نشان می‌دهد ثبت autoload در namespace مورد انتظار انجام نشده است. در اصلاح بعدی، ثبت autoloadها و ارجاع‌های Engine به‌صورت صریح با namespace ریشه‌ای `::DiscourseBaleNotifications` انجام می‌شود و خط خالی گزارش‌شده حذف می‌گردد. این تغییر هنوز باید با CI تازه تأیید شود.

### دستهٔ چهاردهم: آخرین تخلف سبک RuboCop — ۱۵ اکتبر ۲۰۲۶

در اجرای [CI شمارهٔ 38749919779](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38749919779)، `backend_tests` و `check_for_tests` موفق شدند و آزمون‌های `zeitwerk:check`، reloading و RSpec نیز عبور کردند. تنها شکست باقی‌مانده در `linting` بود: یک تخلف `Style/IfUnlessModifier` در `plugin.rb:12`. ثبت ماژول به شرط تک‌خطی تبدیل می‌شود؛ منطق و ترتیب مقداردهی تغییر نمی‌کند. پس از این اصلاح، اجرای تازهٔ CI برای تأیید کامل لازم است.

### وضعیت نهایی پاک‌سازی CI و گام بعد — ۱۵ اکتبر ۲۰۲۶

آخرین اجرای [CI شمارهٔ 38750752257](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38750752257) روی commit `05040efab5c6cae05a2ec110d8bfc811cedd3766` با نتیجهٔ **success** تمام شد. هر سه job موفق بودند: `check_for_tests`، `linting` و `backend_tests`. در lint، RuboCop و Syntax Tree موفق شدند؛ در backend نیز `zeitwerk:check` برای eager load و reloading، بررسی bootability و آزمون‌های RSpec افزونه موفق بودند. خطای نهایی RuboCop در commit «Fix final RuboCop modifier offense» رفع شد.

#### آنچه تأیید شده است

- تخلف‌های RuboCop در این اجرای CI: صفر؛ job مربوطه موفق است.
- بارگذاری کلاس‌ها و مسیرهای autoload: بررسی eager-load و reloading موفق است.
- آزمون‌های backend افزونه: موفق.
- بررسی ترجمهٔ انگلیسی: موفق.
- شاخهٔ کاری: `docs/initial-audit-roadmap`؛ آخرین commit تأییدشدهٔ CI: `05040efab5c6cae05a2ec110d8bfc811cedd3766`.
- ادغام در شاخهٔ اصلی و استقرار روی سایت: انجام نشده‌اند.

#### مرحلهٔ بعد پیشنهادی

از اینجا پاک‌سازی lint و خطاهای مسدودکنندهٔ بارگذاری را بسته‌شده در نظر بگیرید و وارد **بازبینی رفتاری و پوشش آزمون‌ها** شوید. ابتدا diff مجموعهٔ اصلاحات را نسبت به مبنای پیش از این دسته‌ها بازبینی کنید؛ سپس برای مسیرهای حساس، آزمون‌های مشخص را بررسی/تکمیل کنید: احراز هویت وب‌هوک و محدودیت نرخ، پردازش پیام و callback، payload ارسالی به API بله، خطاهای HTTP/شبکه و پاسخ غیر JSON، اتصال/قطع اتصال کاربر، endpointهای مدیریتی و ثبت ترجیحات اعلان. هر تغییر بعدی باید کوچک و مبتنی بر آزمون باشد. پس از تکمیل این بازبینی، گزارش CI تازه بگیرید و فقط با اجازهٔ صریح، دربارهٔ ادغام یا استقرار اقدام کنید.


### آخرین پیگیری آزمون‌ها — ۱۵ اکتبر ۲۰۲۶

اجرای [CI شمارهٔ 38756265646](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38756265646) آزمون‌های backend/RSpec و شناسایی آزمون‌ها را با موفقیت گذراند، اما lint به‌دلیل سه تخلف RuboCop در API client و helper آزمون مستقل شکست خورد. این موارد اصلاح و در نقشه‌راه ثبت شده‌اند؛ تا زمان اجرای مجدد و موفقیت هر دو workflow روی آخرین commit، وضعیت کلی CI را موفق تلقی نکنید. ادغام PR شمارهٔ ۱ همچنان منوط به تأیید این اجراهاست.


پیگیری CI: اجرای [38758938533](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38758938533) نشان داد smoke tests و backend/RSpec موفق، اما lint به‌دلیل یک directive زائد RuboCop در آزمون مستقل ناموفق است. directive اصلاح شده و باید اجرای جدید روی commit تازه بررسی شود؛ تا آن زمان CI کامل موفق محسوب نمی‌شود.


### پیگیری CI: اصلاح نهایی directive آزمون مستقل

در اجرای [Discourse Plugin CI شمارهٔ 38806862001](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38806862001)، backend/RSpec و `check_for_tests` موفق بودند، اما RuboCop با `Lint/MissingCopEnableDirective` در `test/link_code_test.rb` شکست خورد. بررسی خود فایل نشان داد که directive هنوز به‌صورت خط جداگانه پیش از helper بود؛ بنابراین اصلاح قبلی در HEAD جاری اعمال نشده بود. directive اکنون روی خط تعریف همان helper قرار گرفته و در commit `5da56cbda6c8052b7d036573065a5aa67203e021` ثبت شده است. این اصلاح تا زمانی که هر دو workflow روی همین HEAD جدید سبز نشوند، تأیید نهایی CI محسوب نمی‌شود. [PR #1](https://github.com/serkhelesheyi/discourse-bale-notifications/pull/1) همچنان draft است و هنوز ادغام نشده است.


### وضعیت فعلی بازبینی و ادغام

PR شمارهٔ [#1](https://github.com/serkhelesheyi/discourse-bale-notifications/pull/1) پس از موفقیت هر دو workflow روی HEAD نهایی PR، در ۱۵ اکتبر ۲۰۲۶ ادغام شد. commit ادغام: `ece39105a0c7ec69191e9e881d0e70befb2d9b0d`. اجرای [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38808102922) و [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38808102056) روی HEAD نهایی PR هر دو موفق بودند.

پس از ادغام، workflowهای مربوط به خود commit ادغام اجرا شدند و نتیجهٔ آن‌ها در زمان ثبت اولیه در انتظار بود: [smoke tests پس از ادغام](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38808698752) و [Discourse Plugin CI پس از ادغام](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38808699319). بنابراین موفقیت پیش از ادغام را نباید جایگزین تأیید CI پس از ادغام یا آخرین HEAD مستندات کرد. وضعیت دقیق این اجراها و HEAD جاری را در GitHub Actions و [نقشهٔ راه](ROADMAP.md) پیگیری کنید.

این PR تغییرات را وارد شاخهٔ اصلی کرد؛ استقرار افزونه روی سایت عملیاتی انجام نشده است. شاخهٔ کاری هنوز حذف نشده و حذف آن تنها پس از بررسی ancestry و اطمینان از نبود تغییر مستقل ادغام‌نشده مجاز است.

## وضعیت فعلی مخزن — ۱۶ اکتبر ۲۰۲۶ (راستی‌آزمایی نهایی CI)

- PR شمارهٔ [#1](https://github.com/serkhelesheyi/discourse-bale-notifications/pull/1) در شاخهٔ `main` ادغام شده است: `ece39105a0c7ec69191e9e881d0e70befb2d9b0d`.
- [Discourse Plugin CI پس از ادغام](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38808699319) و [Plugin smoke tests پس از ادغام](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38808698752) روی commit ادغام موفق شده‌اند.
- [Smoke tests روی آخرین HEAD مستندات main](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38808768520) موفق است.
- در SHA مستندات قبلی `553473876d3789f9ced4550a2f9c26d7d42379f8` اجرای کامل Discourse Plugin CI لغو شده است ([run 38808769535](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38808769535))؛ بنابراین نتیجهٔ کامل CI روی آخرین HEAD باید جداگانه تأیید شود.
- شاخهٔ کاری `docs/initial-audit-roadmap` در مقایسه با `main` صفر commit جلو و شش commit عقب دارد. شاخه فعلاً حذف نشده؛ حذف آن اقدام پاک‌سازی مستقلی است و در اجرای فعلی ابزار حذف ref در دسترس نبود.
- **هیچ استقرار عملیاتی انجام نشده است.** برای جزئیات شواهد و مراحل باقیمانده، [نقشه‌راه](ROADMAP.md) را ببینید.


## Current verification status — 16 October 2026

- Both GitHub Actions workflows completed successfully on commit [`97d19d10af37c9bfad1f436099e5882506360eeb`](https://github.com/serkhelesheyi/discourse-bale-notifications/commit/97d19d10af37c9bfad1f436099e5882506360eeb): [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38813842853) and [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38813842481).
- The staging acceptance and rollback procedure is documented in [`STAGING_ACCEPTANCE.md`](STAGING_ACCEPTANCE.md).
- The staging checklist has not yet been executed; successful CI does not prove end-to-end behavior against a live Discourse staging instance.
- No production deployment has been performed. See [`ROADMAP.md`](ROADMAP.md) for the current stage and remaining acceptance work.

## Latest CI and release gate — 16 October 2026

Both GitHub Actions workflows passed on commit `91fcbf657b45bbde017f8f01c6845adf3f15b080`: [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38815756869) and [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38815756777). The full CI jobs for linting, test discovery, backend bootability/loader checks, and plugin RSpec succeeded; the smoke workflow's Ruby syntax and standalone service tests also succeeded.

The next release gate is live staging acceptance. Follow [`STAGING_ACCEPTANCE.md`](STAGING_ACCEPTANCE.md) and record evidence for each test. The staging matrix has **not** been marked complete without an actual staging run; automated CI does not prove end-to-end Bale delivery or rollback behavior. No production deployment has been performed.

## Latest CI verification — 16 October 2026

Both workflows passed on candidate commit `fef00db7c44ad997156fb5d2c2d850c08c489185`: [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38818772655) and [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38818772243). Live staging acceptance remains pending; follow [STAGING_ACCEPTANCE.md](STAGING_ACCEPTANCE.md) and record actual evidence before making a release decision. No production deployment has been performed.


## وضعیت ممیزی و آزمون‌ها — ۱۷ اکتبر ۲۰۲۶

اجرای کامل [Discourse Plugin CI شمارهٔ 39027925986](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39027925986) و [Plugin smoke tests شمارهٔ 39027925701](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39027925701) روی commit مستندات c96916378248acebf32d597891b79843ef24c32d موفق شد. CI کامل شامل linting، کشف آزمون‌ها و آزمون‌های backend/RSpec بود. قرارداد پاسخ API اکنون برای پاسخ‌های موفق‌نما با HTTP status ناموفق و پاسخ‌های ناقص آزمون رگرسیون دارد.

در مرحلهٔ بعد، آزمون‌های رگرسیون برای ترجیحات شخصی اعلان، بازه‌های ساعات سکوت (از جمله عبور از نیمه‌شب و منطقهٔ زمانی گیرنده) و انتقال پرچم سکوت به payload پیام متنی/عکس افزوده شده‌اند. **این آزمون‌های تازه هنوز منتظر اجرای CI هستند**؛ تا اعلام نتیجهٔ workflowها، آن‌ها را تأییدشده محسوب نکنید.

این آزمون‌های خودکار، تحویل واقعی در بله، رفتار UI روی نصب زنده یا پذیرش staging را اثبات نمی‌کنند. ماتریس [STAGING_ACCEPTANCE.md](STAGING_ACCEPTANCE.md) همچنان باید در محیط staging اجرا و با شواهد ثبت شود. هیچ استقرار یا تغییری روی تولید در این مرحله انجام نشده است.


## پیگیری شکست CI — ۱۷ اکتبر ۲۰۲۶

در [Discourse Plugin CI شمارهٔ 39029010244](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39029010244)، smoke tests موفق بودند اما RuboCop و یک مثال RSpec شکست خوردند. آزمون منطقهٔ زمانی نامعتبر به‌اشتباه تلاش می‌کرد مقدار ردشده توسط اعتبارسنجی مدل Discourse را در پایگاه داده ذخیره کند؛ اکنون مقدار نامعتبر فقط در سطح آزمون stub می‌شود تا رفتار fail-open خود job سنجیده شود. دو تخلف RuboCop نیز با حذف فاصلهٔ اضافی و استثنای محدود برای طول گروه آزمون payload اصلاح شدند. نتیجهٔ این اصلاحات تا پایان CI جدید تأییدشده نیست.

گام بعدی پس از CI سبز: آزمون قرارداد deliver_notification برای انتقال واقعی flag ساعات سکوت به send_notification و سپس آزمون مسیر ترجیحات کاربر. هیچ استقرار تولیدی انجام نشده است.


## آزمون انتقال ساعات سکوت به لایهٔ ارسال — ۱۷ اکتبر ۲۰۲۶

دو آزمون job به مجموعه افزوده شده‌اند تا بررسی کنند نتیجهٔ محاسبهٔ ساعات سکوت در فراخوانی notifier به پارامتر disable_notification تبدیل می‌شود؛ در ساعات سکوت باید true و در ساعات عادی false باشد. این آزمون‌ها به شبکهٔ بله متصل نمی‌شوند. نتیجهٔ CI اصلاحات قبلی و این commit جدید باید جداگانه بررسی شود؛ تا سبزشدن workflowها این مرحله تأییدشده نیست. مسیر UI ترجیحات و آزمون end-to-end در staging همچنان باقی است و هیچ استقرار تولیدی انجام نشده است.


## CI follow-up — 17 October 2026

On [Discourse Plugin CI run 39030352207](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39030352207), `backend_tests` and `check_for_tests` passed. The only failure was RuboCop's `Layout/EmptyLines` offense at `spec/jobs/send_bale_notifications_spec.rb:114`. The extra blank line has been removed as a formatting-only fix; a fresh CI run must pass before this stage is considered verified. No production deployment was performed.


## Preference filtering regression tests — 17 October 2026

The previous CI failure was fixed, and both workflows passed on commit `b98c7c3e71fd17fa27c9045d7acd47d50adac10e`: [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39031028624) and [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39031028524). The next regression stage adds job-level coverage that saves `bale_notification_types` to user custom fields, reloads the recipient from the database, and verifies that the job context excludes unselected types and accepts selected types. These backend tests do not by themselves prove that the browser preferences form persists changes correctly; that UI path still needs frontend/staging acceptance. No production deployment was performed.


## آخرین وضعیت تأییدشده — ۱۷ اکتبر ۲۰۲۶

آخرین commit دارای تغییرات کد/آزمون که هر دو workflow روی آن موفق شده‌اند [`5d56a2d3cf1c5e424094a604616ec1b1150c8e5e`](https://github.com/serkhelesheyi/discourse-bale-notifications/commit/5d56a2d3cf1c5e424094a604616ec1b1150c8e5e) است. [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39031804664) با موفقیت کامل شده و jobهای linting، کشف آزمون‌ها و backend/RSpec سبز هستند؛ [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39031804370) نیز موفق است.

آزمون‌های job اکنون ترجیحات `bale_notification_types` را پس از ذخیره در custom_fields و بارگذاری مجدد کاربر بررسی می‌کنند. آزمون‌های ساعات سکوت و انتقال پرچم `disable_notification` نیز در مجموعه وجود دارند. این شواهد آزمون backend هستند و به‌تنهایی ثابت نمی‌کنند که چک‌باکس‌های فرم GJS در مرورگر به‌درستی ذخیره و پس از بارگذاری مجدد بازیابی می‌شوند.

**گام بعدی:** ممیزی و آزمون مسیر UI ترجیحات تا ذخیره‌سازی Discourse؛ سپس تکمیل آزمون callbackها و اجرای چک‌لیست [STAGING_ACCEPTANCE.md](STAGING_ACCEPTANCE.md). هیچ تغییر یا استقرار تولیدی در این مرحله انجام نشده است.


## آخرین گیت‌های تأیید — ۱۷ اکتبر ۲۰۲۶

- مرحلهٔ آزمون backend برای ترجیحات ذخیره‌شده بسته شد: job پس از ذخیره و بارگذاری مجدد کاربر، نوع اعلان انتخاب‌شده/نشده را درست فیلتر می‌کند.
- خطای lint از نوع `Layout/EmptyLines` اصلاح شد. CI کامل و smoke tests روی commit کد/آزمون `5d56a2d3` موفق‌اند و هر دو workflow روی commit مستنداتی پیشین `47b193ba` نیز سبز شده‌اند؛ اجرای CI برای این به‌روزرسانی مستندات باید جداگانه بررسی شود.
- گام بعد، بررسی قرارداد واقعی ذخیره‌سازی فرم ترجیحات GJS است؛ تغییر مستقیم `model.custom_fields` نباید بدون اثبات قرارداد Discourse معادل ذخیره‌سازی پایدار فرض شود.
- تا پذیرش staging و آزمون restore، این وضعیت به معنی آمادگی انتشار نیست. هیچ استقرار تازه‌ای روی تولید انجام نشده است. برای ترتیب کار و معیارهای خروج، [نقشه‌راه](ROADMAP.md) و [چک‌لیست پذیرش staging](STAGING_ACCEPTANCE.md) را ببینید.


## پیگیری تازهٔ ذخیره‌سازی ترجیحات — ۱۷ اکتبر ۲۰۲۶

در بازبینی فرم GJS ترجیحات کاربر، تغییر مستقیم ویژگی تو‌در‌توی `model.custom_fields` به‌عنوان خطری برای ثبت تغییر در dirty tracking مدل شناسایی شد. در commit `5ba8662e9f6473c38bcd2c88b0a89a36bcd7df7e`، مقدار `custom_fields` با یک شیء جدید از طریق `model.set(...)` ثبت می‌شود. این اصلاح هنوز منتظر CI روی commit مربوط و آزمون عملی ذخیره/بارگذاری مجدد در staging است؛ بنابراین پایداری واقعی UI هنوز تأییدشده نیست. هیچ استقرار تولیدی انجام نشده است. جزئیات و معیارهای خروج در [ROADMAP.md](ROADMAP.md) و [STAGING_ACCEPTANCE.md](STAGING_ACCEPTANCE.md) ثبت می‌شوند.


## اصلاح انتخاب صفر نوع اعلان — ۱۷ اکتبر ۲۰۲۶

علت برگشتن همهٔ چک‌باکس‌ها پس از خاموش‌کردن همه شناسایی شد: مقدار خالی هم برای «هیچ گزینه‌ای انتخاب نشده» و هم برای «رفتار پیش‌فرض legacy؛ همهٔ انواع فعال» استفاده می‌شد. اکنون `__none__` نشان‌دهندهٔ انتخاب صریح صفر نوع است و فیلتر ارسال نیز آن را به‌عنوان خاموش‌بودن همهٔ انواع می‌شناسد؛ مقدار خالی همچنان برای سازگاری قبلی به معنای دریافت همهٔ انواع فعال است. آزمون‌های backend افزوده شده‌اند. CI و آزمون مرورگر staging باید پیش از بستن این مورد تأیید شوند؛ هیچ استقرار تولیدی انجام نشده است.


## وضعیت آزمون callback — ۱۸ اکتبر ۲۰۲۶

دو آزمون request به وب‌هوک افزوده شده‌اند: callback معتبر از چتِ متصل‌نشده و callbackی که به پست حذف‌شده اشاره می‌کند. انتظار این است که هر دو بدون استثنای کنترل‌نشده پاسخ داده شوند و پیام «اقدام دیگر در دسترس نیست» برای callback برگردد. این آزمون‌ها رفتار ورودی نامعتبر/منقضی را در backend پوشش می‌دهند؛ جایگزین آزمون واقعی لایک/آنلایک و پاسخ در staging نیستند. نتیجهٔ CI باید روی commit نهایی این تغییر و اسناد بررسی شود.


## فیلترهای اعلان Discourse و وضعیت بررسی — ۱۸ اکتبر ۲۰۲۶

افزونه پیش از قرار دادن تحویل Bale در صف، فیلترهای ثبت‌شدهٔ `DiscoursePluginRegistry.push_notification_filters` را روی کاربر و payload اجرا می‌کند. اگر هر فیلتر اعلان را رد کند، job ارسال Bale enqueue نمی‌شود. این رفتار با آزمون سرویس برای هر دو حالت اجازه و رد پوشش داده شده است.

آخرین commit کد/آزمون تأییدشده در CI برای این اصلاح `34d7d5e600f7cfcee642bd38ec2b2c4b6b47ad7c` است: [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39099280010) و [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39099279900) هر دو موفق‌اند. این تأیید به معنی پذیرش staging یا استقرار تولید نیست؛ آزمون واقعی فرم ترجیحات، تعامل‌های بله، دکمه‌های کهنه، بازیابی پشتیبان و rollback همچنان لازم‌اند. هیچ استقرار تولیدی انجام نشده است.


## اصلاح ثبت ذخیره‌سازی ترجیحات — ۱۸ اکتبر ۲۰۲۶

ممیزی قرارداد frontend هسته نشان داد که برای ذخیرهٔ فیلدهای سفارشی از صفحهٔ ترجیحات پروفایل، باید API رسمی `addSaveableCustomFields("profile")` ثبت شود؛ جایگزینی شیء با `model.set("custom_fields", ...)` به‌تنهایی تضمین نمی‌کند که ویژگی در payload ذخیره‌سازی صفحه وارد شود. initializer مربوط در commit [`e2f5b08`](https://github.com/serkhelesheyi/discourse-bale-notifications/commit/e2f5b08b11e59bc4add138c5a2b82b8fc84f6d19) افزوده شد. مستندات مرجع: [Discourse Plugin API](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/plugin-api.gjs) و [تغییر API در Discourse 2026.1](https://releases.discourse.org/changelog/v2026.1.0-latest/).

[آزمون smoke](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39100026940) روی commit کد موفق است؛ CI کامل روی همان SHA باید تأیید شود. این مخزن زیرساخت مستقل آزمون frontend/GJS ندارد و برای این تغییر محدود چارچوب تازه‌ای اضافه نشده است. آزمون مرورگر و ذخیره/بازخوانی پس از reload در staging همچنان باز است. هیچ استقرار یا تغییری روی تولید انجام نشده است.


## تأیید CI نهایی — ثبت ذخیره‌سازی ترجیحات — ۱۸ اکتبر ۲۰۲۶

هر دو workflow روی HEAD مستندات `e2be9a8d674f31cd90f798b20d963e2869e9a46a` موفق‌اند: [Discourse Plugin CI run 39100085147](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39100085147) و [Plugin smoke tests run 39100084929](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39100084929). بنابراین گیت CI خودکار برای initializer ثبت `addSaveableCustomFields("profile")` و مستندات مربوط بسته است. این نتیجه آزمون مرورگر را اثبات نمی‌کند؛ A16 و آزمون end-to-end، تعامل‌های واقعی بله و بازیابی/rollback همچنان نیازمند staging هستند. هیچ استقرار یا تغییری روی تولید انجام نشده است.

## مسیر بعدی: پذیرش محدود با حساب مدیر روی انجمن فعلی

آخرین CI و smoke tests روی HEAD مستندات `b8cc335f23ee0f7faad004ff00edd30df59e8637` موفق‌اند: [CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39100620762) و [smoke](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39100620632). چون محیط staging جداگانه موجود نیست، گام بعدی پذیرش محدود با حساب خود کاربر از طریق به‌روزرسانی خود افزونه در رابط مدیریت انجمن است. کاربر اعلام کرده است که این روش به restart داکر/انجمن نیاز ندارد؛ در این مرحله هیچ تغییر سروری دیگری در برنامه نیست.

چک‌لیست اجرایی و معیارهای توقف در [ROADMAP.md](ROADMAP.md) و [STAGING_ACCEPTANCE.md](STAGING_ACCEPTANCE.md) ثبت شده‌اند. آزمون زنده هنوز انجام نشده است؛ به‌ویژه ذخیره و reload ترجیحات، حالت «هیچ‌کدام»، و کنترل تحویل اعلان‌ها باید واقعاً بررسی شوند. CI سبز به معنی پذیرش زنده نیست.


## گزارش پذیرش زنده — ۱۸ اکتبر ۲۰۲۶

پس از به‌روزرسانی افزونه از پنل انجمن، کاربر این موارد را در محیط واقعی تأیید کرد: ترجیحات جزئی پس از reload حفظ می‌شوند؛ هر هشت گزینه در حالت خاموش پس از reload خاموش می‌مانند؛ با فعال‌بودن همهٔ گزینه‌ها پیام ورودی باعث اعلان بله می‌شود؛ لایک و لغو لایک از داخل بله درست کار می‌کنند؛ با غیرفعال‌کردن گزینهٔ پیام خصوصی، پیام بعدی اعلان بله ایجاد نمی‌کند؛ و اعلان تستی پنل مدیریت دریافت می‌شود.

CI و smoke tests برای SHA مستندات 0cbdb51fa39536818dac71edc28381bb72074ad1 نیز موفق‌اند: [CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39101182350) و [smoke](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39101182110).

این نتیجه‌ها پذیرش اولیهٔ زنده را تقویت می‌کنند، اما هنوز اثبات نمی‌کنند که با خاموش‌بودن هر هشت گزینه هیچ نوع اعلانی ارسال نمی‌شود؛ همچنین پاسخ از داخل بله، callbackهای کهنه، جداسازی حساب‌ها و restore/rollback هنوز بررسی نشده‌اند. برای جزئیات و گام‌های بعد، [نقشه‌راه](ROADMAP.md) و [چک‌لیست پذیرش](STAGING_ACCEPTANCE.md) را ببینید.


## Live acceptance update — 18 October 2026

The user additionally confirmed that all eight notification preferences remained off after save/reload, a new private message produced no Bale notification while all were off, and another private message produced a notification after the preferences were re-enabled. This confirms the all-off preference state and suppression/delivery behavior for the tested private-message event on the live forum. Other notification types have not thereby been individually validated. Bale reply, stale/deleted-post callbacks, cross-account isolation, and backup restore/rollback remain outstanding live checks.


## قالب پیام‌ها در بله

متن پیام‌های ارسالی بله با Markdown قالب‌بندی می‌شود؛ برای لینک از ساختار `[متن](آدرس)` استفاده می‌شود. قالب‌های اعلان فارسی و انگلیسی به Markdown تبدیل شده‌اند. اعلان پیام خصوصی عنوان گفتگو را با برچسب «موضوع پیام خصوصی» نشان می‌دهد و پیام راهنمای اتصال توضیح می‌دهد که می‌توان با Reply به اعلان در بله پاسخ داد تا پاسخ در انجمن ثبت شود. پس از به‌روزرسانی این نسخه، این موارد باید در محیط واقعی دوباره بررسی شوند.


در خود اعلان پیام خصوصی نیز راهنمای کوتاه Reply نمایش داده می‌شود تا کاربر بداند می‌تواند روی همان اعلان پاسخ بزند و متن را به انجمن بفرستد. این رفتار باید پس از نصب نسخهٔ جدید در بله بررسی شود.


## اصلاحات پاسخ از بله و متن اعلان پیام خصوصی — ۱۸ اکتبر ۲۰۲۶

- پیام موفقیت پاسخ در بله از قالب Markdown استفاده می‌کند؛ لینک «مشاهدهٔ پاسخ» باید به URL پست تازه‌ساخته‌شده برسد. پارامتر صریح `parse_mode: html` حذف شده است، زیرا مسیر اعلان‌ها از Markdown استفاده می‌کند و قالب HTML باعث ناسازگاری لینک پاسخ می‌شد.
- اعلان پیام خصوصی عنوان را با برچسب روشن «موضوع پیام خصوصی» نشان می‌دهد و راهنمای کوتاه Reply را نیز در همان اعلان درج می‌کند.
- پیام خوشامد کاربر متصل‌شده نیز راهنمای پاسخ‌دادن با Reply در بله را دارد.
- آزمون‌های request برای مسیر پاسخ و آزمون متن اعلان، قرارداد Markdown و متن عنوان پیام خصوصی را بررسی می‌کنند. در اجرای CI مورخ ۱۸ اکتبر، شکست مشخص شد: انتظار آزمون هنوز `parse_mode: html` را الزام می‌کرد؛ این انتظار اصلاح شده است. اصلاحات قالب‌بندی RuboCop نیز ثبت شده‌اند؛ وضعیت نهایی CI برای commitهای اصلاحی باید از Actions تأیید شود.
- آزمون خودکار، رندرشدن واقعی لینک در کلاینت بله را به‌تنهایی اثبات نمی‌کند؛ پس از به‌روزرسانی افزونه، پاسخ واقعی به یک اعلان آزمایشی را در بله انجام دهید و لینک را باز کنید. هیچ استقرار تولیدی از طریق این تغییرات GitHub انجام نشده است.


## عیب‌یابی ریپلای اول روی اعلان

اگر اولین ریپلای روی اعلان به‌جای ثبت پاسخ، پیام عمومی راهنمای ربات را برگرداند، ابتدا باید شکل payload ورودی وب‌هوک ثبت شود؛ این رفتار را نباید بدون شواهد به خرابی لینک یا ذخیره‌سازی پاسخ نسبت داد. شاخهٔ تشخیصی `diagnose-first-bale-reply` یک تنظیم اختیاری به نام `bale_notifications_webhook_diagnostics_enabled` دارد که پیش‌فرض آن خاموش است. هنگام فعال‌بودن، فقط نام کلیدها، وجود فیلدها و نوع داده‌ها را در لاگ ثبت می‌کند و متن پیام یا مقادیر شناسه‌ها را ثبت نمی‌کند. این تنظیم باید فقط برای یک بازهٔ آزمون کوتاه روشن و بلافاصله پس از جمع‌آوری شواهد خاموش شود. تا وقتی CI، بررسی PR و آزمون زنده کامل نشده‌اند، این قابلیت تشخیصی را نصب‌شده یا تأییدشده تلقی نکنید.

## وضعیت بررسی تشخیصی ریپلای اول — ۱۸ اکتبر ۲۰۲۶

- [x] تغییر تشخیصی در PR شمارهٔ [۲](https://github.com/serkhelesheyi/discourse-bale-notifications/pull/2) ادغام شد؛ commit: `df5089736b51f7f696efad1333b32272188c4142`.
- [x] CI کامل روی HEAD پیش از ادغام موفق شد ([run #39112724492](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39112724492)) و smoke tests نیز موفق بودند ([run #39112724350](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39112724350)).
- [x] تنظیم `bale_notifications_webhook_diagnostics_enabled` به‌طور پیش‌فرض خاموش است؛ لاگ فقط شکل payload را ثبت می‌کند، نه متن پیام یا مقادیر شناسه‌ها.
- [ ] به‌روزرسانی کنترل‌شدهٔ افزونه روی سرور و تأیید نسخهٔ نصب‌شده.
- [ ] فعال‌کردن تنظیم فقط برای آزمون کوتاه؛ ثبت یک ریپلای اول ناموفق و ریپلای بعدی موفق؛ جمع‌آوری خطوط `[BaleNotifications diagnostic]`.
- [ ] خاموش‌کردن تنظیم بلافاصله پس از آزمون و تأیید خاموش‌بودن آن.
- [ ] تحلیل شواهد واقعی، تعیین علت و پیاده‌سازی اصلاح همراه آزمون رگرسیون.

**وضعیت استقرار:** ادغام GitHub هیچ تغییری روی سرور ایجاد نمی‌کند. تا زمان آزمون زنده، علت نهایی و اصلاح رفتاری تأیید نشده‌اند.


## اصلاح وضعیت دکمهٔ پسندیدن در اعلان‌های بله — ۱۸ اکتبر ۲۰۲۶

در بررسی کد مشخص شد که متن دکمه بر اساس شمارش رکوردهای `UserAction` تعیین می‌شد؛ اما مسیر لغو پسندیدن، رکورد فعال `PostAction` را حذف/غیرفعال می‌کند. بنابراین منبع وضعیت دکمه با منبع واقعی وضعیت پسندیدن یکسان نبود و می‌توانست پس از لغو موفق، دکمهٔ «لغو پسندیدن» را باقی بگذارد.

- [x] تعیین وضعیت دکمه بر پایهٔ وجود `PostAction` فعال برای همان کاربر و پست.
- [x] افزودن آزمون رفت‌وبرگشت: پسندیدن ← لغو پسندیدن ← بازگشت به پسندیدن.
- [ ] تأیید CI کامل و smoke tests روی شاخهٔ اصلاح.
- [ ] پس از ادغام و به‌روزرسانی افزونه از پنل مدیریت، آزمون زندهٔ پسندیدن و لغو پسندیدن در همان اعلان.

این تغییر در شاخهٔ `fix-bale-like-button-state` است و هنوز به انجمن تولیدی اعمال نشده است.


## وضعیت اصلاح دکمهٔ پسندیدن — ۱۸ اکتبر ۲۰۲۶

در PR [شمارهٔ ۳](https://github.com/serkhelesheyi/discourse-bale-notifications/pull/3)، وضعیت دکمه بر اساس پسندیدن فعال در PostAction تعیین می‌شود. در نخستین اجرای CI، RuboCop سه تخلف طول متد/بلوک را گزارش کرد؛ کد و آزمون‌ها بازآرایی شده‌اند تا با قواعد موجود سازگار باشند، بدون غیرفعال‌کردن lint. اجرای تأییدی روی HEAD جدید هنوز لازم است. این تغییر هنوز ادغام یا روی انجمن تولیدی مستقر نشده است؛ جزئیات و معیار پذیرش در ROADMAP.md آمده است.
