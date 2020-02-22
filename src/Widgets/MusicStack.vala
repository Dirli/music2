namespace Music2 {
    public class Widgets.MusicStack : Interfaces.StackWrapper {
        private Widgets.ColumnsView columns_view;

        public MusicStack (Gtk.Window win, GLib.Settings settings_ui) {
            source_type = Enums.SourceType.LIBRARY;

            welcome_screen = new Granite.Widgets.Welcome (_("Get Some Tunes"), _("Add music to your library."));
            welcome_screen.append ("document-import", _("Import Music"), _("Import music from a source into your library."));
            welcome_screen.append ("folder-music", _("Change Music Folder"), _("Load music from a folder, a network or an external disk."));
            welcome_screen.activated.connect (on_welcome_activated);

            add_named (welcome_screen, "welcome");

            iter_hash = new Gee.HashMap<uint, Gtk.TreeIter?> ();

            columns_view = new Widgets.ColumnsView ();
            columns_view.filter_list.connect ((category, val) => {
                columns_view.clear_columns (category);
                list_store.clear ();
                iter_hash.clear ();
            });

            var browser_pane = new Gtk.Paned (Gtk.Orientation.VERTICAL);
            browser_pane.expand = true;
            settings_ui.bind ("column-browser-height", browser_pane, "position", GLib.SettingsBindFlags.DEFAULT);

            browser_pane.pack1 (columns_view, false, false);
            browser_pane.pack2 (init_list_view (Enums.Hint.MUSIC), true, false);

            list_store.set_sort_column_id (Enums.ListColumn.ARTIST, Gtk.SortType.ASCENDING);
            list_store.set_sort_func (0, list_sort_func);
            tree_sel = list_view.get_selection ();


            add_named (browser_pane, "listview");
            visible_child_name = "welcome";
        }

        public void init_selections (Enums.Category? select_category) {
            columns_view.init_selections (select_category);
        }

        public override void clear_stack () {
            set_visible_child_name ("welcome");

            columns_view.clear_columns (null);
            list_store.clear ();
            iter_hash.clear ();
        }

        public bool add_iter (CObjects.Media m) {
            GLib.Mutex mutex = GLib.Mutex ();
            mutex.lock ();

            Gtk.TreeIter iter;
            list_store.insert_with_values (out iter, -1,
                 Enums.ListColumn.TRACKID, m.tid,
                 Enums.ListColumn.TRACK, m.track,
                 Enums.ListColumn.ALBUM, m.album,
                 Enums.ListColumn.LENGTH, m.length,
                 Enums.ListColumn.TITLE, m.title,
                 Enums.ListColumn.ARTIST, m.artist);

            iter_hash[m.tid] = iter;

            mutex.unlock ();
            return true;
        }

        public void add_column_item (Structs.Iter iter) {
            columns_view.add_column_item (iter);
        }

        private void on_welcome_activated (int index) {
            if (index == 0) {

            } else if (index == 1) {

            } else {

            }
        }

        public int list_sort_func (Gtk.TreeModel store, Gtk.TreeIter a, Gtk.TreeIter b) {
            int rv = 1;
            int sort_column_id;
            Gtk.SortType sort_direction;
            list_store.get_sort_column_id (out sort_column_id, out sort_direction);

            if (sort_column_id < 1) {return 0;}

            GLib.Value? val_a;
            store.get_value (a, sort_column_id, out val_a);

            GLib.Value? val_b;
            store.get_value (b, sort_column_id, out val_b);

            if (val_a != null && val_b != null) {
                switch (sort_column_id) {
                    case Enums.ListColumn.ARTIST:
                    case Enums.ListColumn.ALBUM:
                    case Enums.ListColumn.TITLE:
                        string a_str = val_a.get_string ();
                        string b_str = val_b.get_string ();
                        rv = Tools.String.compare (a_str, b_str);
                        break;
                }

            }

            if (sort_direction == Gtk.SortType.DESCENDING) {
                rv = (rv > 0) ? -1 : 1;
            }

            return rv;
        }
    }
}
