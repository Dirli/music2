namespace Music2 {
    public abstract class Interfaces.StackWrapper : Gtk.Stack {
        public signal void selected_row (uint row_id, Enums.SourceType source_type);
        public signal void popup_media_menu (Enums.Hint hint, uint[] tids);

        public abstract void clear_stack ();

        protected Gee.HashMap<uint, Gtk.TreeIter?> iter_hash;

        protected Gtk.ListStore list_store;
        protected Enums.SourceType source_type;
        protected string current_view { get; set; }

        protected LViews.ListView list_view;
        protected Granite.Widgets.AlertView alert_view { get; set; }
        protected Granite.Widgets.Welcome welcome_screen { get; set; }

        protected Gtk.TreeSelection tree_sel;

        public bool has_list_view {
            get {return list_view != null;}
        }

        public bool has_alert_view {
            get {return alert_view != null;}
        }

        public bool has_welcome_screen {
            get {return welcome_screen != null;}
        }

        protected void on_row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {
            Gtk.TreeIter? iter;
            list_store.get_iter (out iter, path);

            if (iter != null) {
                GLib.Value text;
                list_store.get_value (iter, Enums.ListColumn.TRACKID, out text);
                selected_row ((uint) text, source_type);
            }
        }

        protected Gtk.ScrolledWindow init_list_view (Enums.Hint hint) {
            list_store = new Gtk.ListStore.newv (Enums.ListColumn.get_all ());

            list_view = new LViews.ListView (hint);
            list_view.set_model (list_store);
            tree_sel = list_view.get_selection ();

            list_view.popup_media_menu.connect ((popup_hint) => {
                Gtk.TreeModel mod;
                uint[] tids = {};
                var paths_list = tree_sel.get_selected_rows (out mod);

                paths_list.foreach ((iter_path) => {
                    Gtk.TreeIter iter;
                    if (list_store.get_iter (out iter, iter_path)) {
                        uint tid;
                        list_store.@get (iter, Enums.ListColumn.TRACKID, out tid);
                        tids += tid;
                    }
                });

                popup_media_menu (popup_hint, tids);
            });

            var scrolled_view = new Gtk.ScrolledWindow (null, null);
            scrolled_view.add (list_view);
            scrolled_view.expand = true;

            list_view.row_activated.connect (on_row_activated);

            return scrolled_view;
        }

        public void select_run_row (uint tid) {
            if (iter_hash.has_key (tid) && has_list_view) {
                GLib.Idle.add (() => {
                    var iter = iter_hash[tid];
                    tree_sel.select_iter (iter);

                    Gtk.TreeModel mod;
                    var paths_list = tree_sel.get_selected_rows (out mod);

                    if (paths_list.length () > 0) {
                        list_store.set (iter, Enums.ListColumn.ICON, new GLib.ThemedIcon ("audio-volume-high-symbolic"), -1);

                        var column = list_view.get_column (0);
                        if (column != null) {
                            var cells = column.get_cells ();
                            if (cells.length () > 0) {
                                list_view.set_cursor_on_cell (paths_list.nth_data (0), column, cells.nth_data (0), false);
                            }
                        }
                    }

                    return false;
                });
            }
        }

        public void remove_run_icon (uint tid) {
            if (iter_hash.has_key (tid) && has_list_view) {
                list_store.set (iter_hash[tid], Enums.ListColumn.ICON, null, -1);

                Gtk.TreeModel mod;
                var paths_list = tree_sel.get_selected_rows (out mod);

                if (paths_list.length () > 0) {
                    tree_sel.unselect_path (paths_list.nth_data (0));
                }
            }
        }

        public void show_welcome () {
            if (has_welcome_screen) {
                visible_child_name = "welcome";
            }
        }

        public void show_alert () {
            if (has_alert_view) {
                visible_child_name = "alert";
            }
        }

        public void hide_alert () {
            visible_child_name = current_view;
        }
    }
}
