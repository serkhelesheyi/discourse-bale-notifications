import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsBaleNotificationsController extends Controller {
  @tracked testUsername = "";
  @tracked testing = false;
  @tracked testStatus = "idle";

  get testSucceeded() {
    return this.testStatus === "success";
  }

  get testFailed() {
    return this.testStatus === "failure";
  }

  @action
  updateTestUsername(event) {
    this.testUsername = event.target.value;
  }

  @action
  async sendTest() {
    const username = (this.testUsername || "").trim();

    if (!username) {
      return;
    }

    this.testing = true;
    this.testStatus = "idle";

    try {
      await ajax("/bale/admin/test", {
        type: "POST",
        data: { username },
      });

      this.testStatus = "success";
    } catch (error) {
      this.testStatus = "failure";
      popupAjaxError(error);
    } finally {
      this.testing = false;
    }
  }
}
