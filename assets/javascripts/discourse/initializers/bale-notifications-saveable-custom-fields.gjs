import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-bale-notifications-saveable-custom-fields",

  initialize() {
    withPluginApi((api) => {
      // The connector is rendered on the user preferences profile page.
      // Register custom_fields explicitly so the preferences save request
      // includes bale_notification_types instead of silently dropping it.
      api.addSaveableCustomFields("profile");
    });
  },
};
