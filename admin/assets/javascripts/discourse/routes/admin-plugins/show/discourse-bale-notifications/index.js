import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

// فاز سه - اصلاح #۱۵: صفحه‌ی وضعیت مدیریتی، طبق قرارداد استاندارد دیسکورس
// برای صفحات ادمین افزونه‌ها (admin/routes/admin-plugins-<route-name>.js،
// هم‌راستا با add_admin_route "bale_notifications.title", "bale-notifications"
// در plugin.rb). این تنها بخشی از این فاز است که چون امکان اجرای زنده در
// محیط توسعه وجود نداشت، با اطمینان کمی کمتر از بقیه‌ی کد تحویل داده می‌شود؛
// در صورت لود نشدن مسیر /admin/plugins/bale-notifications پس از rebuild،
// این فایل اولین جای قابل‌بررسی است.
export default class AdminPluginsBaleNotificationsRoute extends DiscourseRoute {
  model() {
    return ajax("/bale/admin/status");
  }
}
