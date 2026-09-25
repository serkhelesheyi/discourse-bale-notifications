export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",

  map() {
    this.route(
      "discourse-bale-notifications",
      { path: "bale-notifications" }
    );
  },
};
