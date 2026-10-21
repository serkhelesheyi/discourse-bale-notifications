# Staging Acceptance and Rollback Runbook

This runbook is for validating the Bale Notifications Discourse plugin in a non-production staging instance. It is not evidence that staging or production testing has already happened.

## 1. Entry criteria

- [ ] The staging instance is disposable or backed up, and its Discourse version is recorded.
- [ ] The candidate is the exact `main` commit under review; record `git rev-parse HEAD` or the checked-out SHA.
- [ ] A staging-only Bale bot token and webhook secret are available. Never reuse production credentials in staging.
- [ ] The staging operator can rebuild/restart Discourse, inspect application and Sidekiq logs, and restore the pre-test state.
- [ ] Outbound connectivity to the Bale API is permitted from staging.
- [ ] A test account and a second account are available; do not use real user data.
- [ ] The current backup/restore procedure has been checked before making changes.

**Stop conditions:** do not proceed if the target is production, credentials are uncertain, the rollback path is unverified, or the candidate SHA differs from the one approved for testing.

## 2. Capture the baseline

Record the date/time and timezone, staging URL (do not publish secrets), Discourse version, plugin SHA, relevant companion-plugin versions, enabled plugin settings, and current health of web/Sidekiq/Redis. Save redacted baseline logs and confirm a recent restorable backup or snapshot exists.

## 3. Install and configure

1. Install or update the plugin only on staging using the project's established Discourse plugin procedure.
2. Rebuild/restart using the site's normal operator workflow.
3. Confirm the plugin loads without Ruby exceptions, missing translations, autoload errors, or repeated Sidekiq failures.
4. Configure a staging-only bot token and secret. Do not paste secrets into issue comments, logs, screenshots, or this runbook.
5. Verify that the configured endpoint/secret arrangement matches the plugin's actual configuration and deployment design; do not expose an unauthenticated webhook.

## 4. Acceptance matrix

| ID | Test | Expected result | Evidence / outcome |
|---|---|---|---|
| A01 | Plugin boot and admin settings | Plugin loads; settings are visible and persist after reload | Pending staging run |
| A02 | Valid user link code | Intended test account links successfully once | Pending staging run |
| A03 | Invalid, expired, and reused link codes | Each is rejected safely; no unintended account link | Pending staging run |
| A04 | Normal notification route | Supported notification reaches only the linked test account | Pending staging run |
| A05 | Private/personal-message route | Supported message notification is delivered according to settings and privacy expectations | Pending staging run |
| A06 | Preferences and notification types | Each supported preference changes delivery as documented; unsupported/unverified types are recorded, not assumed | Pending staging run |
| A07 | Like then unlike | Like creates an active like, unlike removes it, callback feedback is correct, and the inline keyboard reflects the resulting state | Pending staging run |
| A08 | Invalid callback / malformed update | Request is rejected or safely ignored; no exception loop or unintended state change | Pending staging run |
| A09 | Deleted post / disconnected account | Missing content or disconnected account is handled safely without leaking content | Pending staging run |
| A10 | Quiet hours, including midnight crossover | Messages are deferred/suppressed according to configured timezone and policy | Pending staging run |
| A11 | API timeout, network error, non-JSON and malformed API response | Failure is contained; retries/jobs behave as designed; no unhandled exception loop | Pending staging run |
| A12 | API error response | Failure is recorded in a useful, redacted form and does not report false success | Pending staging run |
| A13 | Secret and content redaction | Tokens, secrets, private message bodies, and sensitive payloads do not appear in logs | Pending staging run |
| A14 | Disable plugin | New plugin activity stops as expected; no recurring job/error storm remains | Pending staging run |
| A15 | Regression and resource health | Core forum actions still work; web and Sidekiq remain healthy; no growing queue or repeated errors | Pending staging run |
| A16 | Bale preference persistence | Toggle preferences, save/reload; all-off state suppresses a supported event and enabled state delivers it | **Partial pass on live forum**: persistence and private-message suppression/delivery confirmed by user report; other types not individually tested |

For each row record **Pass / Fail / Blocked / Not applicable**, test account(s), timestamp, concise observations, and links to redacted logs. Never mark a row Pass solely because a unit test or GitHub Actions workflow passed.

## 5. Failure handling

- Stop testing if there is unintended cross-account delivery, secret exposure, persistent job failures, unexpected data mutation, or forum instability.
- Preserve redacted logs and the failing test ID before changing anything, if doing so is safe.
- Do not retry a test that could create duplicate messages or account links until its side effects are understood.
- File a focused issue with the candidate SHA, test ID, expected/actual behavior, and redacted evidence. Do not include tokens, secrets, private message contents, or personal data.

## 6. Rollback procedure

1. Disable the plugin or its outbound delivery using the site's documented operational method.
2. Stop the acceptance run and confirm no further test notifications are being sent.
3. If the candidate changed the staging deployment, restore the previously recorded plugin revision and follow the site's normal rebuild/restart procedure.
4. Restore the pre-test snapshot only if test data or application state was altered and restoration is appropriate; understand that restoring a full snapshot may discard later staging work.
5. Verify web/Sidekiq health, queue behavior, plugin-disabled behavior, and absence of repeated exceptions.
6. Record the rollback reason, restored SHA/snapshot identifier, time, and post-rollback checks.

Do not perform these steps against production as part of this checklist. Production deployment requires a separate explicit authorization and a production-specific maintenance/rollback plan.

## 7. Exit criteria

- [ ] Every applicable acceptance row has a recorded outcome and evidence.
- [ ] No unresolved critical/high-severity failure remains.
- [ ] Logs are reviewed for secret/content leakage.
- [ ] Plugin disable/rollback path has been demonstrated on staging.
- [ ] The results, environment versions, candidate SHA, and decision are recorded in `ROADMAP.md`.
- [ ] A separate release decision is made. Passing staging is necessary evidence, not automatic authorization to deploy production.

## Current execution status

- GitHub CI on commit `97d19d10af37c9bfad1f436099e5882506360eeb` is successful for both workflows (see links in `ROADMAP.md`).
- Staging acceptance has **not** been executed or verified by this document.
- Production deployment has **not** been performed.

## Latest automated verification — 16 October 2026

Candidate documentation/code HEAD: `91fcbf657b45bbde017f8f01c6845adf3f15b080`.

- [x] [Discourse Plugin CI run 38815756869](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38815756869) completed with `success`: `ci / linting`, `ci / check_for_tests`, and `ci / backend_tests` all succeeded. The backend job reports successful Zeitwerk eager-load/reloading checks, bootability, English locale lint, and plugin RSpec.
- [x] [Plugin smoke tests run 38815756777](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38815756777) completed with `success`: Ruby syntax checks and standalone service tests succeeded.
- [ ] Live staging acceptance: not evidenced by GitHub Actions and still requires execution on the actual staging instance.

These CI results establish automated checks for the exact SHA above. They do not certify Bale API behavior, webhook configuration, privacy in a real forum, or rollback on a deployed instance.

## Latest CI re-check — 16 October 2026

The following workflows completed successfully for candidate commit `fef00db7c44ad997156fb5d2c2d850c08c489185`:

- [x] [Discourse Plugin CI run 38818772655](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38818772655): completed / success.
- [x] [Plugin smoke tests run 38818772243](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/38818772243): completed / success.
- [ ] Live staging acceptance remains unexecuted/unverified. Do not mark A01–A15 as passing without actual staging evidence.
- [ ] Record the exact SHA actually installed on staging. The CI candidate above is the tested code revision; documentation-only commits may advance `main` after it.

No production deployment has been performed. Production release requires separate explicit authorization.


## Additional preference persistence check — 17 October 2026

A16 specifically validates the GJS-to-Discourse model save path. Run it only on staging with a linked test account and record the exact plugin SHA and Discourse version. Check both the rendered checkbox state after reload and, where safely available, the persisted `bale_notification_types` custom field. When every enabled type is selected, the expected stored value is an empty string (legacy unrestricted behavior). When none is selected, the expected stored value is the explicit sentinel `__none__`, and the delivery job must suppress every type. Also verify one selected/one deselected after a reload. Do not treat CI or backend job specs as a substitute for this browser check. This test has not yet been executed.


## Clarification for A16 — explicit empty selection

The persisted preference contract distinguishes three states:

- Missing/empty string: legacy unrestricted behavior (all site-enabled types).
- `__none__`: user explicitly deselected every type; no Bale notification type should be delivered.
- A pipe-separated list: only those listed types may be delivered.

For A16, verify that selecting no checkboxes survives save/reload as all unchecked and that a supported test notification is not delivered to that account. Also verify selecting all checkboxes survives reload and continues to use the legacy empty-string value. This clarification describes the candidate implementation; it is not evidence that the staging test has run.


## Callback regression note — 18 October 2026

Automated request coverage now includes a syntactically valid callback from an unlinked private chat and a callback referencing a missing/deleted post. These cases must be acknowledged safely and answered as unavailable. This does not replace staging checks for successful like/unlike, replies, stale keyboard buttons, or cross-account isolation. Record actual outcomes and redacted evidence before marking any acceptance row as passed.


## Automated interaction coverage — 18 October 2026

The request suite now includes success-path cases for like, unlike, and replying to a stored notification. They verify the local like state, callback feedback/keyboard refresh calls, mapping of a Bale message ID to the original post, and the arguments passed to Discourse's `NewPostManager`. The Bale API calls are mocked. These tests are not a staging pass: A07 and the real Bale reply flow remain **Pending staging run** until exercised with staging-only credentials and accounts. Also verify stale buttons and cross-account isolation before marking interaction acceptance complete.


## Automated interaction coverage update — 18 October 2026

The request suite now also covers callback account isolation (the linked account identified by the incoming private chat must be the actor; another linked account must not receive the action) and an unlike callback when no active like exists. CI previously exposed and prompted fixes for an unsupported `PostAction.remove_act` class call, keyboard expectation argument types, reply-manager mocking, and two RuboCop line-length offenses. These fixes are committed, but this section is not a staging pass: wait for green CI on the final candidate SHA, then run A07–A09 with staging-only credentials and record actual evidence.

## Latest automated verification — 18 October 2026

Candidate SHA: `34d7d5e600f7cfcee642bd38ec2b2c4b6b47ad7c`.

- [x] [Discourse Plugin CI run 39099280010](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39099280010) completed successfully.
- [x] [Plugin smoke tests run 39099279900](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39099279900) completed successfully.
- [x] Automated service specs cover both cases for `push_notification_filters`: all filters allow delivery, and a blocking filter prevents the Bale job from being enqueued.
- [ ] A07–A09 and the real preference/browser flow remain pending staging execution. Include stale callback buttons and cross-account isolation in the run; do not mark these rows passed based on mocked tests.
- [ ] Backup restoration and plugin disable/rollback still require staging evidence.

These CI checks apply to the exact candidate SHA above. They do not prove live Bale delivery, browser persistence, webhook configuration, or rollback. Staging acceptance has not been performed, and production has not been changed.


## Preference save-path update — 18 October 2026

The candidate adds an initializer that calls `api.addSaveableCustomFields("profile")` because the Bale connector is rendered on the profile preferences page. The official Discourse plugin API documents this method as ensuring the entire `custom_fields` object is included in the selected preferences page's save payload. This complements the component's `model.set("custom_fields", ...)`; neither CI nor this source review proves the browser request persisted the field.

Candidate code commit: [`e2f5b08b11e59bc4add138c5a2b82b8fc84f6d19`](https://github.com/serkhelesheyi/discourse-bale-notifications/commit/e2f5b08b11e59bc4add138c5a2b82b8fc84f6d19).

- [x] Smoke workflow run [39100026940](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39100026940) passed on the candidate code SHA.
- [ ] Record final Discourse Plugin CI result for the candidate SHA before treating code CI as passed.
- [ ] Run A16 on staging after recording exact Discourse version and installed plugin SHA: select one type and deselect another, save and reload; select all and verify stored empty string; select none and verify `__none__` and all boxes remain unchecked after reload.
- [ ] Confirm a test notification is suppressed when `__none__` is saved and that a selected type is delivered when allowed by site settings.
- [ ] Do not use production for this test. Do not mark A16 passed without browser evidence and a staging-only account.

Reference: [Discourse Plugin API](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/plugin-api.gjs), method `addSaveableCustomFields(page)`; [API introduced in Discourse 2026.1](https://releases.discourse.org/changelog/v2026.1.0-latest/).


## Final CI gate for preference save-path candidate — 18 October 2026

- [x] Discourse Plugin CI [run 39100085147](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39100085147) passed on documentation HEAD `e2be9a8d674f31cd90f798b20d963e2869e9a46a`, which includes the preference-save initializer and the runbook updates.
- [x] Plugin smoke tests [run 39100084929](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39100084929) passed on the same SHA.
- [ ] A16 is still pending actual staging browser evidence: partial selection, all selected, none selected, save/reload persistence, and delivery suppression for `__none__`.
- [ ] A07–A09, stale callbacks, cross-account isolation, backup restore, and rollback remain pending staging execution.
- [ ] Do not treat the green CI run as evidence of a deployed staging instance or production acceptance. No production deployment has been performed.

Next action: identify/prepare a non-production staging instance, record its Discourse version and installed plugin SHA, and execute the matrix above with staging-only credentials.

## مسیر جایگزین پذیرش زنده بدون staging — ۱۸ اکتبر ۲۰۲۶

کاربر تأیید کرده است که staging مستقل در اختیار ندارد، کاربر فعالی برای افزونه وجود ندارد و آزمون را می‌تواند با حساب خودش انجام دهد. او همچنین گفته است که به‌روزرسانی خود افزونه از رابط مدیریت انجمن نیازی به restart Docker یا Discourse ندارد. این runbook اکنون برای **آزمون محدود با حساب خود کاربر در انجمن موجود** نیز قابل استفاده است؛ این مسیر همچنان آزمون روی محیط عملیاتی است و باید محتاطانه اجرا شود.

### پیش‌شرط‌ها

- ثبت SHA/نسخهٔ فعلی نصب‌شده و تأیید پشتیبان معتبر پیش از به‌روزرسانی.
- به‌روزرسانی فقط خود افزونه از رابط مدیریت؛ هیچ بازسازی کانتینر، تغییر `app.yml`، تنظیم شبکه یا تغییر سروری دیگری در این مرحله.
- استفاده فقط از حساب خود کاربر و اعلان آزمایشی محدود؛ از آزمون با حساب کاربران دیگر یا ارسال انبوه پرهیز شود.
- آخرین گیت خودکار روی HEAD `b8cc335f23ee0f7faad004ff00edd30df59e8637` سبز است: [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39100620762) و [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39100620632).

### اجرای A16 — ذخیره و بازخوانی ترجیحات

1. در ترجیحات پروفایل، یک نوع اعلان را فعال و نوع دیگری را غیرفعال کنید؛ ذخیره و reload کنید و هر دو وضعیت را بررسی کنید.
2. همهٔ انواع را فعال کنید؛ ذخیره و reload کنید. انتظار: همهٔ چک‌باکس‌ها فعال باقی بمانند؛ قرارداد فعلی مقدار خالی/legacy را برای همهٔ انواع به کار می‌برد.
3. همهٔ انواع را غیرفعال کنید؛ ذخیره و reload کنید. انتظار: همه خاموش بمانند و مقدار صریح `__none__` حفظ شود.
4. در صورت امکان با یک اعلان آزمایشی کنترل‌شده بررسی کنید نوع منتخب تحویل می‌شود و حالت `__none__` اعلان تحویل نمی‌دهد.
5. اگر انتخاب‌ها بعد از reload برگشتند، اعلان خاموش ارسال شد، یا رفتار غیرمنتظره دیدید، آزمون را متوقف کنید؛ شواهد بدون دادهٔ محرمانه را ثبت کنید و پیش از تغییر بیشتر، علت را بررسی کنید.

### ثبت نتیجه

برای هر مورد، زمان، SHA واقعاً نصب‌شده، نسخهٔ Discourse، نتیجهٔ مورد انتظار/واقعی و شواهد redacted را ثبت کنید. تا زمانی که نتیجهٔ واقعی ثبت نشده، A16 و پذیرش زنده را **Pending** نگه دارید. این سند به‌روزرسانی افزونه را اجرا نمی‌کند و rollback را نیز انجام نداده است.


## Current acceptance status — 20 October 2026

The repository's latest `main` HEAD is `76ae9ee1344f59512e9534ea1327ee8664db4840`. Both required workflows passed on this exact SHA: [Discourse Plugin CI run 39449833056](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39449833056) and [Plugin smoke tests run 39449831969](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39449831969). The commits between the last reviewed code SHA `a5836a1205a8b154d2c3862d3ced58b5eb6b91ca` and current `main` change documentation only; no production command or configuration change was performed in this documentation pass.

**Reported live evidence:** the user reports that the earlier missing webhook URL / Bale like-reply issue was resolved, and prior checks confirmed preference persistence and private-message notification suppression/delivery. The exact installed plugin SHA and Discourse version are not independently verified. This is user-reported evidence, not a complete live acceptance pass.

**Still not established by the current evidence:** live verification of the updated Reply success link and instructions; individual delivery/suppression for each supported notification type; stale/deleted-post callback behavior; cross-account isolation; and backup restore/rollback. Keep these cases pending until actually exercised and record only redacted evidence. A17 remains an accepted operational risk, **not a technical Pass**; further upstream log investigation is deferred at the user's request.

## Live acceptance report — 18 October 2026

After updating the plugin through the forum admin UI, the user reports these real-site checks passed: partial notification preferences remained deselected after reload; all eight preferences remained deselected after reload; an incoming message produced a Bale notification when all options were enabled; like and unlike actions from Bale worked; disabling the private-message notification preference suppressed the next private-message notification; and the admin-panel test notification was delivered.

The documentation HEAD 0cbdb51fa39536818dac71edc28381bb72074ad1 also has green automated workflows: [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39101182350) and [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39101182110).

This is evidence of initial live acceptance, not full acceptance. Still verify event suppression with all eight options off; test other notification types individually where applicable; and retain pending status for Bale replies, stale/deleted-post callbacks, cross-account isolation, and backup restore/rollback until those are exercised. The checklist records the user's report; it does not independently execute or verify the tests.


## Live acceptance update — all preferences off — 18 October 2026

**Reported outcome: PASS for the tested private-message event on the existing live forum.** The user saved all eight notification preferences as off, reloaded the profile and confirmed they remained off, then sent a private message and received no Bale notification. After re-enabling the preferences, a second private message generated the expected notification.

This validates persistence of the explicit all-off selection and delivery suppression/enabled delivery for the private-message route only. It does not establish that all eight notification types have each been tested individually. The result is based on the user's direct report, not independent log inspection. Exact installed plugin SHA and Discourse version have not yet been recorded.


## UX acceptance follow-up — 18 October 2026

The user confirmed that replying to an existing private-message notification in Bale successfully posted a reply to the correct private topic and under the correct account. The user then identified three presentation issues: the success-message link was not clickable, the notification did not explain the Reply workflow, and the phrase equivalent to “in [title]” was ambiguous.

The candidate changes use Bale's documented Markdown link syntax, label the private-message topic explicitly, add a concise Reply instruction, and escape dynamic text for Markdown. **These presentation fixes are not yet live-verified.** After updating the plugin through the forum admin UI, check that (1) the success link opens the created reply, (2) the initial private-message notification has a clickable topic link and a clear “Private-message topic” label, (3) the Reply instruction is visible, and (4) the private-message body remains readable. Do not mark this follow-up as passed before those checks.


The private-message notification itself now includes a short Reply hint (not only the connection/help message). Verify that the hint appears in a newly delivered notification after updating the plugin. This remains pending live verification.

## A17 — لاگ‌های بالادستی وب‌هوک و query-string secret

**وضعیت جاری: ریسک پذیرفته شده و بررسی بیشتر به تصمیم کاربر متوقف است؛ این مورد Pass فنی نیست.** آدرس فعلی webhook کلید احراز هویت را در query string (`key`) حمل می‌کند. فیلتر پارامترهای Rails از لاگ‌های CDN، reverse proxy یا Nginx محافظت نمی‌کند. موارد زیر کارهای deferred برای زمانی‌اند که بررسی دوباره مجاز و مطلوب باشد؛ چک‌باکس‌های باز به معنای انجام‌شدن یا تأیید فنی نیستند.

- [ ] در محیط staging و بدون انتشار مقدار secret، تنظیمات لاگ آروان/CDN را بررسی و ثبت کنید: آیا query string ذخیره می‌شود؟ آیا امکان mask/redact کردن key وجود دارد؟ چه نقش‌هایی به لاگ دسترسی دارند و retention آن چیست؟
- [ ] در صورت وجود reverse proxy/Nginx در origin، قالب access log و سیاست retention را read-only بررسی کنید؛ URL کامل یا secret را در خروجی قابل‌اشتراک چاپ نکنید.
- [ ] نتیجه را با شواهد redacted ثبت کنید و مشخص کنید آیا key در هیچ لاگ قابل دسترس ظاهر می‌شود. اگر نمی‌توان آن را اثبات کرد، وضعیت را Blocked بگذارید، نه Pass.
- [ ] پشتیبانی Bale از هدر/پارامتر secret مخصوص webhook فقط با مستند رسمی یا آزمون کنترل‌شدهٔ staging تأیید شود؛ در نبود شواهد، پارامتر API جدیدی فرض یا استفاده نشود.

**معیار Pass:** شواهد واقعی نشان دهد secret در لاگ‌های قابل دسترس ثبت نمی‌شود یا با کنترل تأییدشده‌ای ماسک/محدود شده است؛ صرف request.filtered_path یا filtered_parameters در آزمون Rails این معیار را برآورده نمی‌کند.

این بررسی فقط روی staging انجام می‌شود. تغییر تنظیمات production، چرخاندن secret یا ثبت مجدد webhook به مجوز و برنامهٔ جداگانه نیاز دارد.

### نتیجهٔ فعلی A17 — ۲۰ اکتبر ۲۰۲۶

**وضعیت: Risk accepted / further investigation deferred by user; not a technical Pass.** در خروجی read-only `nginx -T`، قالب `log_discourse` از `"$request"` استفاده می‌کند؛ این متغیر می‌تواند query string را شامل شود. مقصد access log در خروجی `/var/log/nginx/access.log` بود. از این شواهد نمی‌توان نتیجه گرفت که درخواست وب‌هوک حتماً با همین قالب ثبت می‌شود یا secret واقعاً در لاگ موجود است.

کاربر تصمیم گرفت فعلاً پنل آروان بررسی نشود و بررسی بیشتر لاگ‌های سرور انجام نگیرد، زیرا دسترسی دیگران به لاگ‌ها محدود است. هیچ access log واقعی جست‌وجو یا چاپ نشد و هیچ تنظیمی در production تغییر نکرد. این تصمیم پذیرش عملیاتی ریسک است، نه اثبات محرمانگی کامل؛ موارد مربوط به آروان و مشاهدهٔ لاگ‌ها برای آینده باز گذاشته می‌شوند.


## Live acceptance addendum — reply/mention flows — 20 October 2026

The user reports successful live checks after updating the plugin: private-message and ordinary-reply notifications arrived; a post containing a mention generated a reply notification for the topic/post owner and a mention notification for the mentioned user; replying to the Bale mention notification created a reply under the intended Discourse post; and a subsequent reply in the chain was recorded under the preceding reply with a notification delivered to the expected recipient. Full scenario details and limits are recorded in LIVE_ACCEPTANCE_REPORT.md.

**Status:** these are user-reported manual PASS results for the scenarios exercised, not an independently verified test run. The exact installed plugin SHA and Discourse version remain unrecorded. Replying to the older/original mention notification did not produce a new notification for the mentioned user; this alone does not establish a defect. Keep that edge case pending until the exact Discourse target post and notification policy are checked. Deleted/stale-post callbacks, cross-account isolation, remaining notification types, and backup restore/rollback also remain pending. No production commands or changes were performed while documenting this report.


## Acceptance status correction — 20 October 2026

This addendum supersedes earlier pending notes for the two checks below:

- **PASS (user-confirmed):** the targeted reply-to-an-old-mention-notification test was already run and behaved correctly.
- **PASS (user-confirmed):** cross-account isolation was already tested and behaved correctly.
- **PASS (GitHub CI):** both workflows completed successfully on current HEAD `afd1711847a24d13761e48339f0db6cd032da581`: Discourse Plugin run `39488076484` and Plugin smoke tests run `39488076035`.
- Deleted/stale-post callback handling and an actual backup restore/rollback exercise are not established by this confirmation; keep them pending only if they have not been separately tested.
- The exact installed plugin SHA and Discourse version still need recording to independently establish production/source parity.
- No production commands or changes were made while updating this status.

Next: record installed versions and close only any remaining operational checks that have not already been performed. A17 remains an accepted operational risk, not a technical PASS.


## ثبت نسخهٔ زنده — ۲۱ اکتبر ۲۰۲۶

نسخه‌های مشاهده‌شده با فرمان‌های خواندنی در کانتینر `app`:

- Plugin SHA: `35f34cc5e60ad2aa63b197fdd3e06ff26e85e850`, branch `main`; plugin working tree clean.
- Discourse core SHA: `bab418487a463eede4c7d2f6415fe2eb966a3883`.
- Core repository reports an untracked path `e` (`?? e`); its type and origin are unknown. Do not delete, stage, or modify it before read-only inspection.
- Current GitHub `main` is `6eb2b7fc31eac573d93ff3b89e06cb0a75ae6617`. Comparing installed plugin SHA to this HEAD shows eight docs-only commits, so no code update/rebuild is indicated solely by this difference.
- These checks were read-only and made no production changes.

The installed SHA and core SHA are now recorded. Investigate `e` with read-only metadata commands; keep deleted/stale-post callbacks and restore/rollback pending only if not already independently verified. A17 remains an accepted operational risk, not a technical pass.


## Read-only inspection of the core untracked path and latest CI — 21 October 2026

The user supplied read-only metadata for the core repository's untracked path `e`:

- It is a regular, empty file (0 bytes), owned by `root:root`, mode `0644`, last modified at `2026-09-25 11:18:21 UTC`, and is not a symlink.
- This does not establish its origin. Leave it untouched: do not stage, delete, or modify it based only on this metadata.
- Both workflows succeeded on documentation HEAD `f18481802a65e7881f129553f8ab7cba2389d392`: [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39493976023) and [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39493975015).
- The live plugin remains at `35f34cc5e60ad2aa63b197fdd3e06ff26e85e850`; no production update is warranted solely for docs-only commits.

Next, confirm whether deleted/stale-post callback handling and a safe restore/rollback exercise have already been independently verified. Do not perform a restore exercise on production. A17 remains an accepted operational risk, not a technical PASS.


## User-confirmed operational acceptance — 21 October 2026

- **Deleted/stale-post callback — PASS (user-reported live test):** the user tested the callback on the live forum; liking was unavailable and the bot correctly responded that liking was not possible.
- **Restore/rollback — provisionally accepted by user:** the user asked that this item be treated as confirmed for now and removed from the open checklist. This records an operational acceptance decision; it does **not** claim that a real restore drill was executed or that a full restore was demonstrated. Do not run a restore drill on production.
- The user also confirmed that both CI workflows succeeded. Check the latest linked Actions runs for the exact documentation HEAD before relying on those runs as current evidence.

A17 remains an accepted operational risk, not a technical PASS. The empty untracked core path `e` remains untouched. No production changes were made for this documentation update.


## Current status reconciliation — 21 October 2026

This section supersedes the earlier historical status notes above where they conflict with the latest evidence. The older dated entries are retained as history; they are not a live checklist by themselves.

- Current documentation HEAD at the start of this reconciliation: `2fb9a462049b146a30cc384fe581e0baf47f6044`. The documentation refresh does not change executable plugin code.
- **GitHub CI: PASS** on that HEAD: [Discourse Plugin CI run 39495201493](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39495201493) and [Plugin smoke tests run 39495201171](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39495201171). These are automated repository checks, not a staging deployment.
- **Reported live manual PASS:** the user confirmed private-message notifications, ordinary reply and mention routing, chained Bale Reply posting to the intended Discourse posts, reply to an older mention notification, cross-account isolation, and safe handling of a deleted/stale-post like callback. These are user-reported observations, not independently reproduced here.
- **Staging matrix:** not executed/verified in a separate staging environment. Keep A01–A15 as pending staging checks unless evidence from a genuine non-production run is added. Do not infer a full staging pass from production smoke tests or CI.
- **A16:** partial live pass only for preference persistence and the private-message all-off/on behavior, as described in the historical record; do not extend that result to all notification types.
- **Restore/rollback:** provisionally accepted operationally at the user's request. This is not evidence that a restore drill or full backup recovery has been executed. Do not run a restore exercise on production; any future technical validation must use a non-production environment and an explicitly approved plan.
- **A17:** accepted operational risk; not a technical Pass. Further upstream-log investigation is deferred by the user.
- **Production baseline reported by user:** plugin SHA `35f34cc5e60ad2aa63b197fdd3e06ff26e85e850`; Discourse core SHA `bab418487a463eede4c7d2f6415fe2eb966a3883`. A newer plugin-repository HEAD consists of documentation changes relative to the latest code-validated SHA, so these documentation commits alone do not warrant a production update or rebuild.
- The empty untracked core file `e` remains untouched because its origin is unknown.

No production command, configuration change, secret rotation, rebuild, or deployment was performed while reconciling this document.

## کنترل‌های خودکار retry webhook — ۲۱ اکتبر ۲۰۲۶

این فهرست، پوشش خودکار روی شاخهٔ `fix/retry-webhook-operations` را مشخص می‌کند؛ هیچ‌یک جای آزمون زندهٔ نسخهٔ نصب‌شده را نمی‌گیرد.

- [x] موفقیت ثبت و حذف با پاسخ `ok: true`.
- [x] retry برای `error_code` عددی 429 و 500–599.
- [x] retry برای HTTP status عددی 429 و 500–599، حتی وقتی کد API پاسخ دائمی به نظر می‌رسد.
- [x] retry برای شکست شناخته‌شدهٔ لایهٔ انتقال.
- [x] عدم retry برای خطاهای دائمی، کدهای رشته‌ای/نامعتبر، پاسخ موفق و پاسخ مبهم فاقد metadata.
- [x] سقف retry صریح برابر ۵ تلاش مجدد پس از تلاش اولیه.
- [x] بررسی اینکه پیام‌های جدید لاگ شامل token، secret، URL کامل webhook یا متن خام پاسخ API نیستند.
- [ ] lint، backend tests و smoke روی HEAD نهایی PR موفق شوند.
- [ ] پس از هر ادغام/استقرار آتی، نسخهٔ نصب‌شده و رفتار واقعی webhook جداگانه تأیید شود؛ این شاخه به‌تنهایی تأیید زنده نیست.

**وضعیت عملیاتی:** در این مرحله هیچ فرمانی روی سرور اجرا نشده و هیچ تنظیم، secret، webhook، داده یا کانتینری تغییر نکرده است.


## وضعیت پس از ادغام retry اعلان‌ها — ۲۲ اکتبر ۲۰۲۶

- **PR #15:** ادغام‌شده؛ CI و Smoke موفق روی commit شاخهٔ نهایی پیش از ادغام.
- **PR مربوط به retry webhook:** بازپایه‌گذاری‌شده روی `main` پس از PR #15؛ اجرای کامل CI روی نسخهٔ جدید هنوز لازم است.
- این وضعیت خودکار به معنای آزمون staging یا تأیید webhook زنده نیست.
- هیچ تغییر production، secret، setting، webhook، rebuild یا deployment در این مرحله انجام نشده است.


## وضعیت پس از ادغام PR #17 و ممیزی callback API — ۲۲ اکتبر ۲۰۲۶

- **PR #17: MERGED** — commit `7cc6c6ad0f56527a05e7fa99ab9e4693fe3de13a`.
- **GitHub CI: PASS** روی HEAD نهایی پیش از ادغام، commit `93488de080b4b6609d57702979780b13dc35ee6c`: [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39672731844).
- **Smoke tests: PASS** روی همان HEAD: [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39672731155).
- سیاست retry ثبت/حذف webhook اکنون در `main` است؛ سقف ۵ تلاش مجدد پس از تلاش اولیه و فقط برای خطاهای گذرا/انتقالی که صریحاً قابل طبقه‌بندی هستند.
- ممیزی callbackها تصمیم گرفت فعلاً برای `answerCallbackQuery` و `editMessageReplyMarkup` retry خودکار اضافه نشود. پاسخ callback زمان‌حساس است؛ ویرایش صفحه‌کلید best-effort باقی می‌ماند تا زمانی که طراحی job مستقل و سیاست شکست آزمون‌پذیر تعریف شود.
- آزمون‌های رگرسیون جدید برای پاسخ ناموفق این دو API اضافه شده‌اند؛ آن‌ها باید در CI شاخهٔ جاری تأیید شوند. این تست‌ها جای آزمون دستی یا staging را نمی‌گیرند.
- **Staging acceptance:** اجرای واقعی در محیط staging برای سیاست retry webhook یا callback APIها از این merge استنباط نمی‌شود؛ موارد مربوط را تا آزمون مستقل staging باز نگه دارید.
- **Production:** هیچ rebuild، deploy، تغییر تنظیمات/secretها، تغییر webhook زنده یا فرمان سروری انجام نشده است. این یادداشت به‌تنهایی مجوز به‌روزرسانی production نیست.


## بستن پیگیری PR #17 و PR #18 — ۲۲ اکتبر ۲۰۲۶

- **PR #17: MERGED** — `7cc6c6ad0f56527a05e7fa99ab9e4693fe3de13a`; سیاست retry محدود برای `setWebhook/deleteWebhook` در `main` است.
- **PR #18: MERGED** — `cee53a2b8c7f3cff7cee4dd0b41e359be8fff094`; تصمیم callback و آزمون‌های رگرسیون در `main` هستند.
- **CI PR #18: PASS** — [run 39673603284](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39673603284).
- **Smoke PR #18: PASS** — [run 39673602367](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39673602367).
- **تصمیم callback:** برای `answerCallbackQuery` و `editMessageReplyMarkup` فعلاً retry خودکار نداریم. این تصمیم، محدودیت best-effort بودن پاسخ/ویرایش را می‌پذیرد و تضمین موفقیت callback نیست.
- **گام بعدی واقعی:** اجرای پذیرش روی staging با ثبت SHA افزونه و نسخهٔ Discourse و آزمون کنترل‌شدهٔ سناریوهای retry وب‌هوک و callback. آزمون staging از CI نتیجه‌گیری نمی‌شود.
- **وضعیت production:** هیچ rebuild/deploy، تغییر setting/secret، تغییر webhook زنده یا فرمان سروری انجام نشده است. تا تکمیل پذیرش staging و تصمیم صریح بعدی، production دست‌نخورده می‌ماند.
