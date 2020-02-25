/*
 * Copyright (c) 2020 Dirli <litandrej85@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

namespace Music2 {
    public class Widgets.SourceListView : Granite.Widgets.SourceList {
        public signal void selection_changed (int pid, Enums.Hint hint);
        public signal void menu_activated (Views.SourceListItem menu_item, Enums.ActionType action_type);
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

            if (items_hash.has_key (pid)) {
                return items_hash[pid];
            }

            var sourcelist_item = new Views.SourceListItem (pid, name, hint, icon, activatable_icon);

            sourcelist_item.edited.connect ((new_name) => {
                edited (pid, new_name);
            });

            sourcelist_item.menu_item_activated.connect ((item, action) => {
                menu_activated (item, action);
                if (action == Enums.ActionType.EDIT) {
                    start_editing_item (item);
                } else if (action == Enums.ActionType.RENAME) {
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

        public void remove_item (int pid) {
            if (items_hash.has_key (pid)) {
                var removed_item = items_hash[pid];
                switch (removed_item.hint) {
                    case Enums.Hint.PLAYLIST:
                        playlists_category.remove (removed_item);
                        break;
                    case Enums.Hint.MUSIC:
                        library_category.remove (removed_item);
                        break;
                }
            }
        }
    }
}
