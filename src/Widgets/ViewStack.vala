namespace Music2 {
    public class Widgets.ViewStack : Interfaces.StackWrapper {
        construct {
            expand = true;

            alert_view = new Granite.Widgets.AlertView (_("No Results"), _("Try another search"), "edit-find-symbolic");
            add_named (alert_view, "alert");
        }

        public override void clear_stack () {
            show_alert ();
        }
    }
}
