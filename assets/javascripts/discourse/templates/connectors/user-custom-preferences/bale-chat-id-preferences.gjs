import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { fn, concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

// فاز یک - اصلاح #۸: به‌جای یک ورودی متنی خام که کاربر مستقیماً chat_id را
// در آن کپی می‌کرد (بدون هیچ تاییدیه‌ی برگشتی)، این کامپوننت یک جریان اتصال
// دوطرفه را پیاده‌سازی می‌کند: کاربر از همین‌جا یک کد اتصال کوتاه‌مدت
// می‌سازد و باید همان کد را از چت بله برای ربات ارسال کند. فیلد
// bale_chat_id دیگر مستقیماً از سمت کاربر قابل‌نوشتن نیست.
export default class BaleChatIdPreferences extends Component {
  @service siteSettings;

  @tracked linkCode = null;
  @tracked expiresInMinutes = null;
  @tracked loading = false;
  @tracked connected = Boolean(this.args.model?.custom_fields?.bale_chat_id);
  @tracked selectedTypes = [];

  constructor() {
    super(...arguments);
    // فاز سه - اصلاح #۱۸: خالی‌بودن bale_notification_types یعنی «بدون
    // محدودیت شخصی» - یعنی کاربر همه‌ی انواعی که خودِ سایت فعال کرده را
    // دریافت می‌کند (دقیقاً همان رفتاری که پیش از افزودن این قابلیت وجود داشت).
    const raw = this.args.model?.custom_fields?.bale_notification_types;
    this.selectedTypes = raw ? raw.split("|").filter(Boolean) : [...this.availableTypes];
  }

  get availableTypes() {
    return (this.siteSettings.bale_enabled_notification_types || "")
      .split("|")
      .filter(Boolean);
  }

  // آرایه‌ای از {type, selected} برای رندر ساده و بدون ابهامِ چک‌باکس‌ها.
  get typeRows() {
    const selected = new Set(this.selectedTypes);
    return this.availableTypes.map((type) => ({
      type,
      selected: selected.has(type),
    }));
  }

  @action
  toggleType(type) {
    const current = new Set(this.selectedTypes);
    if (current.has(type)) {
      current.delete(type);
    } else {
      current.add(type);
    }

    const all = this.availableTypes;
    this.selectedTypes = all.filter((t) => current.has(t));

    if (!this.args.model.custom_fields) {
      this.args.model.custom_fields = {};
    }
    // اگر همه‌ی گزینه‌ها انتخاب باقی بمانند، فیلد را خالی ذخیره می‌کنیم تا
    // معنای «بدون محدودیت شخصی» حفظ شود (نه یک رشته‌ی طولانیِ برابر با پیش‌فرض).
    this.args.model.custom_fields.bale_notification_types =
      this.selectedTypes.length === all.length ? "" : this.selectedTypes.join("|");
  }

  @action
  async generateCode() {
    this.loading = true;

    try {
      const result = await ajax("/bale/link", { type: "POST" });
      this.linkCode = result.code;
      this.expiresInMinutes = Math.round((result.expires_in || 0) / 60);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async disconnect() {
    this.loading = true;

    try {
      await ajax("/bale/link", { type: "DELETE" });
      this.connected = false;
      this.linkCode = null;
      this.expiresInMinutes = null;

      if (this.args.model?.custom_fields) {
        this.args.model.custom_fields.bale_chat_id = null;
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div class="control-group bale-notifications-preferences">
      <label class="control-label">{{i18n
          "bale-notifications.preferences-title"
        }}</label>

      <div class="controls">
        {{#if this.connected}}
          <p class="bale-status bale-status--connected">
            {{i18n "bale-notifications.status-connected"}}
          </p>

          {{! فاز سه - اصلاح #۱۸: چک‌باکس ترجیح شخصی، فقط وقتی حساب متصل است. }}
          {{#if this.typeRows.length}}
            <div class="bale-notification-types">
              <div class="bale-notification-types-title">
                {{i18n "bale-notifications.types-title"}}
              </div>
              {{#each this.typeRows as |row|}}
                <label class="bale-type-row">
                  <input
                    type="checkbox"
                    checked={{row.selected}}
                    {{on "change" (fn this.toggleType row.type)}}
                  />
                  {{i18n (concat "bale-notifications.types." row.type)}}
                </label>
              {{/each}}
            </div>
          {{/if}}

          <DButton
            @action={{this.disconnect}}
            @disabled={{this.loading}}
            @label="bale-notifications.disconnect"
            @icon="unlink"
            class="btn-danger bale-disconnect-btn"
          />
        {{else if this.linkCode}}
          <div class="bale-link-code">{{this.linkCode}}</div>
          <div class="instructions">
            {{i18n
              "bale-notifications.send-code-instructions"
              minutes=this.expiresInMinutes
            }}
          </div>
          <DButton
            @action={{this.generateCode}}
            @disabled={{this.loading}}
            @label="bale-notifications.get-new-code"
            class="btn-flat bale-new-code-btn"
          />
        {{else}}
          <DButton
            @action={{this.generateCode}}
            @disabled={{this.loading}}
            @label="bale-notifications.get-code"
            @icon="link"
            class="bale-get-code-btn"
          />
          <div class="instructions">{{i18n "bale-notifications.instructions"}}</div>
        {{/if}}
      </div>
    </div>
  </template>
}
