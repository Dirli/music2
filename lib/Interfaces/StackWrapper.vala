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

        public void add_iter (CObjects.Media m) {
            lock (list_store) {
                Gtk.TreeIter iter;
                list_store.insert_with_values (out iter, -1,
                    Enums.ListColumn.TRACKID, m.tid,
                    Enums.ListColumn.TRACK, m.track,
                    Enums.ListColumn.ALBUM, m.get_display_album (),
                    Enums.ListColumn.LENGTH, m.length,
                    Enums.ListColumn.TITLE, m.get_display_title (),
                    Enums.ListColumn.ARTIST, m.get_display_artist (), -1);

                iter_hash[m.tid] = iter;
            }
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

        private void on_row_inserted (Gtk.TreePath path, Gtk.TreeIter iter) {
            list_store.row_inserted.disconnect (on_row_inserted);
            if (get_child_by_name ("listview") != null) {
                set_visible_child_name ("listview");
            }
        }

        public void show_welcome () {
            if (has_welcome_screen && visible_child_name != "welcome") {
                visible_child_name = "welcome";

                if (has_list_view) {
                    list_store.row_inserted.disconnect (on_row_inserted);
                    list_store.row_inserted.connect (on_row_inserted);
                }
            }
        }

        public void show_alert () {
            if (has_alert_view && visible_child_name != "alert") {
                current_view = visible_child_name;
                visible_child_name = "alert";

                if (has_list_view) {
                    list_store.row_inserted.disconnect (on_row_inserted);
                    list_store.row_inserted.connect (on_row_inserted);
                }
            }
        }

        public void hide_alert () {
            visible_child_name = current_view;
        }
    }
}
