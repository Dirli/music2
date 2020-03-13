namespace Music2 {
    public class Widgets.ActionStack : Gtk.Stack {
        public signal void cancelled_scan ();
        public signal void dnd_button_clicked (Enums.ActionType action_type, string uri);

        // private Views.ProgressBox progress_box;
        // private Views.DnDSelection dnd_selection;

        public ActionStack () {


            var empty_grid = new Gtk.Grid ();
            transition_type = Gtk.StackTransitionType.CROSSFADE;

            add_named (empty_grid, "empty");

            visible_child = empty_grid;
        }

        public void hide_widget (string widget_name) {
            visible_child_name = "empty";
            var removed_widget = get_child_by_name (widget_name);
            if (removed_widget != null) {
                removed_widget.destroy ();
            }
        }

        public void init_progress () {
            if (get_child_by_name ("progress") == null) {
                var progress_box = new Views.ProgressBox ();
                progress_box.cancelled_scan.connect (() => {
                    cancelled_scan ();
                });

                add_named (progress_box, "progress");
            }

            update_progress (0);
            set_visible_child_name ("progress");
        }

        public void init_dnd (Enums.SourceType source_type, string uri) {
            if (get_child_by_name ("dnd") == null) {
                var dnd_selection = new Views.DnDSelection ();
                dnd_selection.button_clicked.connect ((btn_name, uri) => {
                    dnd_button_clicked (btn_name, uri);
                    hide_widget ("dnd");
                });

                add_named (dnd_selection, "dnd");
            }

            (get_child_by_name ("dnd") as Views.DnDSelection).add_data (uri);
            set_visible_child_name ("dnd");
        }

        public void update_progress (double progress_val) {
            var progress_box = get_child_by_name ("progress");
            if (progress_box != null) {
                (progress_box as Views.ProgressBox).update_progress (progress_val);
            }
        }
    }
}
