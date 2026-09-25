import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-bale-notifications";

export default {
  name: "discourse-bale-notifications-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");

    if (!currentUser || !currentUser.admin) {
      return;
    }

    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "bale-notifications.admin.title",
          route: "adminPlugins.show.discourse-bale-notifications",
          description: "bale-notifications.admin.title",
        },
      ]);
    });
  },
};
