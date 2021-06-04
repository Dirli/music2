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
    public class Widgets.MusicStack : Interfaces.StackWrapper {
        public signal void filter_view (Enums.Category cat, int filter_id, Enums.ViewMode view_mode);

        private Widgets.ColumnsView columns_view;

        private Gee.HashMap<int, Interfaces.ColumnBox> categories_hash;
        private Structs.Filter? current_filter;

        private LViews.GridView albums_view;
        private Views.AlbumView album_view;

        private Gtk.TreeModelFilter? list_filter = null;

        public int active_album = -1;

        public MusicStack (Gtk.Window win, GLib.Settings settings_ui, Gtk.ListStore music_store, Gtk.ListStore albums_store) {
            source_type = Enums.SourceType.LIBRARY;

            Structs.Filter default_filter = {};

            default_filter.str = "";
            default_filter.id = 0;

            current_filter = default_filter;

            transition_type = Gtk.StackTransitionType.OVER_DOWN;

            categories_hash = new Gee.HashMap<int, Interfaces.ColumnBox> ();

            welcome_screen = new Granite.Widgets.Welcome (_("Get Some Tunes"), _("Add music to your library."));
            welcome_screen.append ("document-import", _("Import Music"), _("Import music from a source into your library."));
            welcome_screen.append ("folder-music", _("Change Music Folder"), _("Load music from a folder, a network or an external disk."));
            welcome_screen.activated.connect (on_welcome_activated);

            columns_view = new Widgets.ColumnsView ();
            columns_view.refilter.connect ((filter) => {
                if (list_filter != null) {
                    current_filter = filter;

                    list_filter.refilter ();
                }
            });

            foreach (unowned Enums.Category category in Enums.Category.get_all ()) {
                if (category != Enums.Category.N_CATEGORIES) {
                    if (category == Enums.Category.ALBUM) {
                        var column = new Views.ColumnAlbum (category);
                        categories_hash[category] = column;
                        columns_view.add_column (column);
                    } else {
                        var column = new Views.ColumnBrowser (category);
                        categories_hash[category] = column;
                        columns_view.add_column (column);
                    }
                }
            }

            var browser_pane = new Gtk.Paned (Gtk.Orientation.VERTICAL);
            browser_pane.expand = true;
            settings_ui.bind ("column-browser-height", browser_pane, "position", GLib.SettingsBindFlags.DEFAULT);

            browser_pane.pack1 (columns_view, false, false);
            browser_pane.pack2 (init_list_view (Enums.Hint.MUSIC, music_store), true, false);

            albums_view = new LViews.GridView ();
            albums_view.set_columns (-1);
            albums_view.set_model (albums_store);
            albums_view.selection_changed.connect (grid_selection_changed);

            var grid_scrolled = new Gtk.ScrolledWindow (null, null);
            grid_scrolled.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            grid_scrolled.add (albums_view);

            album_view = new Views.AlbumView (win);
            album_view.selected_row.connect ((row_id) => {
                if (active_album > 0 && active_album == album_view.active_album_id) {
                    selected_row (row_id, Enums.SourceType.QUEUE);
                } else {
                    active_album = album_view.active_album_id;
                    selected_row (row_id, source_type);
                }
            });


            var grid_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            grid_pane.pack1 (grid_scrolled, true, false);
            grid_pane.pack2 (album_view, false, false);

            add_named (welcome_screen, "welcome");
            add_named (browser_pane, "listview");
            add_named (grid_pane, "gridview");
            show_welcome ();

            GLib.Idle.add (() => {
                grid_item_activated (null);
                return false;
            });
        }

        protected new void on_row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {
            var filter = columns_view.get_filter ();
            active_album = -1;

            if (filter != null && filter.category == Enums.ListColumn.ALBUM) {
                if (filter.id > 0) {
                    active_album = filter.id;
                }
            }

            var stack_wrapper = this as Interfaces.StackWrapper;
            if (stack_wrapper != null) {
                stack_wrapper.on_row_activated (path, column);
            }
        }

        public Gee.ArrayList<uint>? get_filter_tracks () {
            if (visible_child_name == "gridview") {
                return album_view.get_tracks ();
            } else if (visible_child_name == "listview") {
                var t_array = columns_view.get_tracks ();
                if (t_array.size == 0) {

                }

                return t_array;
            }

            return null;
        }

        protected override uint get_selected_tid (Gtk.TreePath filter_path) {
            if (list_filter != null) {
                Gtk.TreeIter filter_iter;
                if (list_filter.get_iter (out filter_iter, filter_path)) {
                    Gtk.TreeIter child_iter;
                    list_filter.convert_iter_to_child_iter (out child_iter, filter_iter);
                    uint tid;
                    list_store.@get (child_iter, Enums.ListColumn.TRACKID, out tid, -1);
                    return tid;
                }
            }

            return 0;
        }

        public new void select_run_row (Gtk.TreeIter? iter) {
            if (iter != null) {
                album_view.select_run_row (iter);

                var stack_wrapper = this as Interfaces.StackWrapper;
                if (stack_wrapper != null) {
                    stack_wrapper.select_run_row (iter);
                }
            } else {
                Gtk.TreeIter first_iter;
                if (list_store.get_iter_first (out first_iter)) {
                    var first_path = list_store.get_path (first_iter);
                    if (first_path != null) {
                        list_view.set_cursor (first_path, null, false);
                    }
                }
            }
        }

        public new void remove_run_icon (Gtk.TreeIter iter) {
            var stack_wrapper = this as Interfaces.StackWrapper;
            if (stack_wrapper != null) {
                stack_wrapper.remove_run_icon (iter);
            }

            album_view.unselect_rows ();
        }

        public void init_selections (Gtk.TreeIter? iter) {
            categories_hash.foreach ((entry) => {
                entry.value.init_box ();
                return true;
            });

            GLib.Idle.add (() => {
                list_filter = new Gtk.TreeModelFilter (list_store, null);
                list_filter.set_visible_func (row_visible_cb);
                list_view.set_model (list_filter);

                select_run_row (iter);

                var grid_filter = new Gtk.TreeModelFilter (list_store, null);
                grid_filter.set_visible_func (row_visible_cb);

                album_view.set_model (grid_filter);

                return false;
            });
        }

        public void show_view (Enums.ViewMode view_mode) {
            set_visible_child_name (view_mode == Enums.ViewMode.COLUMN ? "listview" : "gridview");
        }

        public override void clear_stack () {
            show_welcome ();

            list_view.set_model (list_store);
            list_filter = null;

            columns_view.clear_columns (null);
            album_view.set_model (null);
        }

        public bool row_visible_cb (Gtk.TreeModel m, Gtk.TreeIter iter) {
            if (current_filter == null) {
                return false;
            }

            if (current_filter.str == "") {
                return true;
            }

            string iter_value;
            uint tid;
            m.@get (iter, current_filter.category, out iter_value, Enums.ListColumn.TRACKID, out tid, -1);

            if (current_filter.str == iter_value) {
                if (visible_child_name == "listview") {
                    columns_view.add_track (tid);
                } else if (visible_child_name == "gridview") {
                    album_view.add_track (tid);
                }

                return true;
            }

            return false;
        }

        public void add_column_item (Enums.Category cat, Gtk.ListStore store) {
            if (categories_hash.has_key (cat)) {
                categories_hash[cat].set_model (store);
            }
        }

        private void on_welcome_activated (int index) {
            if (index == 0) {

            } else if (index == 1) {

            } else {

            }
        }

        private void grid_item_activated (Structs.Album? album_struct) {
            if (album_struct == null) {
                album_view.hide ();
                return;
            }

            if (album_view.active_album_id != album_struct.album_id) {
                album_view.set_album (album_struct);
            }

            album_view.show_all ();
        }

        private void grid_selection_changed () {
            GLib.List<Gtk.TreePath> path = albums_view.get_selected_items ();
            var albums_store = albums_view.get_model ();
            if (path != null && albums_store != null) {
                Gtk.TreeIter selected_iter;
                if (albums_store.get_iter (out selected_iter, path.data)) {
                    unowned Structs.Album? struct_album;
                    albums_store.@get (selected_iter, 0, out struct_album, -1);
                    grid_item_activated (struct_album);

                    return;
                }
            }

            grid_item_activated (null);
        }
    }
}
