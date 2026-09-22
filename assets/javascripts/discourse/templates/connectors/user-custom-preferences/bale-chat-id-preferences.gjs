import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
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
  @tracked linkCode = null;
  @tracked expiresInMinutes = null;
  @tracked loading = false;
  @tracked connected = Boolean(this.args.model?.custom_fields?.bale_chat_id);

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
