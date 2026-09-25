import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsBaleNotificationsController extends Controller {
  @tracked testUsername = "";
  @tracked testing = false;
  // "idle" | "success" | "failure"
  @tracked testStatus = "idle";

  get testSucceeded() {
    return this.testStatus === "success";
  }

  get testFailed() {
    return this.testStatus === "failure";
  }

  // از یک شیء actions کلاسیک استفاده شده (به‌جای {{on}} روی دکمه) چون
  // تمپلیت این کنترلر از {{action "sendTest"}} استفاده می‌کند - سازگارترین
  // الگو با نسخه‌های مختلف Discourse برای صفحات ادمین.
  actions = {
    sendTest: async () => {
      const username = (this.testUsername || "").trim();
      if (!username) {
        return;
      }

      this.testing = true;
      this.testStatus = "idle";

      try {
        await ajax("/bale/admin/test", { type: "POST", data: { username } });
        this.testStatus = "success";
      } catch (error) {
        this.testStatus = "failure";
        popupAjaxError(error);
      } finally {
        this.testing = false;
      }
    },
  };
}
