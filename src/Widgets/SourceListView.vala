namespace Music2 {
    public class Widgets.SourceListView : Granite.Widgets.SourceList {
        public signal void selection_changed (int pid, Enums.Hint hint);
        public signal void menu_activated (Views.SourceListItem menu_item, string action_name);
        public signal void edited (int pid, string new_name);

        private Granite.Widgets.SourceList.ExpandableItem library_category;
        private Granite.Widgets.SourceList.ExpandableItem devices_category;
        private Granite.Widgets.SourceList.ExpandableItem network_category;
        private Views.PlayListCategory playlists_category;

        private Gee.HashMap<int, Views.SourceListItem> items_hash;

        public SourceListView () {
            base (new Views.SourceListRoot ());

            items_hash = new Gee.HashMap<int, Views.SourceListItem> ();

            library_category = new Granite.Widgets.SourceList.ExpandableItem (_("Library"));
            devices_category = new Granite.Widgets.SourceList.ExpandableItem (_("Devices"));
            network_category = new Granite.Widgets.SourceList.ExpandableItem (_("Network"));
            playlists_category = new Views.PlayListCategory (_("Playlists"));

            root.add (library_category);
            root.add (devices_category);
            root.add (network_category);
            root.add (playlists_category);
            root.expand_all (false, false);

            add_item (-1,
                      _("Music"),
                      Enums.Hint.MUSIC,
                      new ThemedIcon ("library-music")
            );

            Gtk.TargetEntry uri_list_entry = { "text/uri-list", Gtk.TargetFlags.SAME_APP, 0 };
            enable_drag_dest ({ uri_list_entry }, Gdk.DragAction.COPY);
        }

        public void select_active_item (int pid) {
            if (items_hash.has_key (pid)) {
                selected = items_hash[pid];
            }
        }

        public void update_badge (int pid, int val) {
            items_hash[pid].badge = val.to_string ();
        }

        public Granite.Widgets.SourceList.Item add_item (int pid,
                                                         string name,
                                                         Enums.Hint hint,
                                                         GLib.Icon icon,
                                                         GLib.Icon? activatable_icon = null) {

            var sourcelist_item = new Views.SourceListItem (pid, name, hint, icon, activatable_icon);

            sourcelist_item.edited.connect ((new_name) => {
                edited (pid, new_name);
            });

            sourcelist_item.menu_item_activated.connect ((item, action) => {
                menu_activated (item, action);
                if (action == "edit") {
                    start_editing_item (item);
                } else if (action == "rename") {
                    start_editing_item (item);
                }
            });

            switch (hint) {
                case Enums.Hint.MUSIC:
                    library_category.add (sourcelist_item);
                    break;
                case Enums.Hint.PLAYLIST:
                    sourcelist_item.editable = true;
                    playlists_category.add (sourcelist_item);
                    break;
                case Enums.Hint.QUEUE:
                case Enums.Hint.READ_ONLY_PLAYLIST:
                    sourcelist_item.editable = false;
                    playlists_category.add (sourcelist_item);
                    break;
                default:
                    break;
            }

            items_hash[pid] = sourcelist_item;
            return sourcelist_item;
        }

        public override void item_selected (Granite.Widgets.SourceList.Item? item) {
            if (item is Views.SourceListItem) {
                var sidebar_item = item as Views.SourceListItem;
                selection_changed (sidebar_item.pid, sidebar_item.hint);
            }
        }

        public void rename_playlist (int pid, string modified_name) {
            if (items_hash.has_key (pid)) {
                items_hash[pid].name = modified_name;
            }
        }

        public void remove_playlist (int pid) {
            if (items_hash.has_key (pid)) {
                var removed_item = items_hash[pid];
                switch (removed_item.hint) {
                    case Enums.Hint.PLAYLIST:
                        playlists_category.remove (removed_item);
                        break;
                }
            }
        }
    }
}
