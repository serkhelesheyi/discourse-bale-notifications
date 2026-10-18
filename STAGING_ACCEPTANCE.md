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


## Live acceptance report — 18 October 2026

After updating the plugin through the forum admin UI, the user reports these real-site checks passed: partial notification preferences remained deselected after reload; all eight preferences remained deselected after reload; an incoming message produced a Bale notification when all options were enabled; like and unlike actions from Bale worked; disabling the private-message notification preference suppressed the next private-message notification; and the admin-panel test notification was delivered.

The documentation HEAD 0cbdb51fa39536818dac71edc28381bb72074ad1 also has green automated workflows: [Discourse Plugin CI](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39101182350) and [Plugin smoke tests](https://github.com/serkhelesheyi/discourse-bale-notifications/actions/runs/39101182110).

This is evidence of initial live acceptance, not full acceptance. Still verify event suppression with all eight options off; test other notification types individually where applicable; and retain pending status for Bale replies, stale/deleted-post callbacks, cross-account isolation, and backup restore/rollback until those are exercised. The checklist records the user's report; it does not independently execute or verify the tests.


## Live acceptance update — all preferences off — 18 October 2026

**Reported outcome: PASS for the tested private-message event on the existing live forum.** The user saved all eight notification preferences as off, reloaded the profile and confirmed they remained off, then sent a private message and received no Bale notification. After re-enabling the preferences, a second private message generated the expected notification.

This validates persistence of the explicit all-off selection and delivery suppression/enabled delivery for the private-message route only. It does not establish that all eight notification types have each been tested individually. The result is based on the user's direct report, not independent log inspection. Exact installed plugin SHA and Discourse version have not yet been recorded.
