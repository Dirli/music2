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
        public signal void selected_row (uint row_id, Enums.Hint hint);
        public signal void popup_media_menu (Enums.Hint hint, uint[] tids, Gdk.Rectangle rect, Gtk.Widget w);

        private bool show_selected = true;

        public abstract void clear_stack ();
        protected abstract uint get_selected_tid (Gtk.TreePath iter_path);

        protected Gtk.ListStore list_store;

        protected Enums.Hint hint { get; set; }
        protected string view_name { get; set; }

        protected LViews.ListView list_view;
        protected Gtk.TreeSelection tree_sel;

        protected bool has_list_view {
            get {return list_view != null;}
        }

        construct {
            transition_type = Gtk.StackTransitionType.OVER_RIGHT;

            notify["visible-child-name"].connect (on_changed_child);
        }

        private void on_changed_child () {
            var v_name = get_visible_child_name ();
            if (list_store == null || v_name == null) {
                return;
            }

            if (v_name != "listview" && v_name != "gridview") {
                list_store.row_inserted.disconnect (on_row_inserted);
                list_store.row_inserted.connect (on_row_inserted);
            } else {
                view_name = v_name;
            }
        }

        protected void on_row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {
            Gtk.TreeIter? iter;
            list_view.model.get_iter (out iter, path);

            if (iter != null) {
                GLib.Value text;
                list_view.model.get_value (iter, (int) Enums.ListColumn.TRACKID, out text);
                selected_row ((uint) text, hint);
            }
        }

        protected Gtk.ScrolledWindow init_list_view () {
            list_view = new LViews.ListView (hint);

            tree_sel = list_view.get_selection ();

            list_view.popup_media_menu.connect ((x_point, y_point) => {
                int cell_x, cell_y;
                Gtk.TreePath? cursor_path;
                Gtk.TreeViewColumn? cursor_column;
                list_view.get_path_at_pos ((int) x_point, (int) y_point, out cursor_path, out cursor_column, out cell_x, out cell_y);

                uint[] tids = {};
                unowned Gtk.TreeModel mod;
                var paths_list = tree_sel.get_selected_rows (out mod);

                bool contains_cursor_path = false;
                paths_list.foreach ((iter_path) => {
                    if (!contains_cursor_path) {
                        contains_cursor_path = cursor_path != null && iter_path.compare (cursor_path) == 0 ? true : false;
                    }

                    var tid = get_selected_tid (iter_path);

                    if (tid > 0) {
                        tids += tid;
                    }
                });

                if (!contains_cursor_path && cursor_path != null) {
                    tree_sel.unselect_all ();
                    tree_sel.select_path (cursor_path);

                    var tid = get_selected_tid (cursor_path);

                    if (tid > 0) {
                        tids = {tid};
                    }
                }

                Gdk.Rectangle rect = {};

                rect.x = (int) x_point;
                rect.y = (int) y_point;
                rect.height = 1;
                rect.width = 1;

                popup_media_menu (hint, tids, rect, list_view);
            });

            var scrolled_view = new Gtk.ScrolledWindow (null, null);
            scrolled_view.add (list_view);
            scrolled_view.expand = true;
            scrolled_view.scroll_event.connect ((e) => {
                show_selected = false;
                return false;
            });

            list_view.row_activated.connect (on_row_activated);

            return scrolled_view;
        }

        public void select_run_row (Gtk.TreeIter iter) {
            if (list_store == null) {
                return;
            }

            GLib.Idle.add (() => {
                list_store.@set (iter, (int) Enums.ListColumn.ICON, new GLib.ThemedIcon ("audio-volume-high-symbolic"), -1);

                if (show_selected) {
                    Gtk.TreePath? sel_path = null;
                    if (list_view.model is Gtk.TreeModelFilter) {
                        var child_path = list_store.get_path (iter);
                        if (child_path != null) {
                            var filter_model = list_view.model as Gtk.TreeModelFilter;
                            if (filter_model != null) {
                                sel_path = filter_model.convert_child_path_to_path (child_path);
                            }
                        }

                    } else {
                        sel_path = list_store.get_path (iter);
                    }

                    if (sel_path != null) {
                        list_view.set_cursor (sel_path, null, false);
                    }
                } else {
                    show_selected = true;
                }

                return false;
            });
        }

        public void remove_run_icon (Gtk.TreeIter iter) {
            list_store.@set (iter, (int) Enums.ListColumn.ICON, null, -1);

            if (!show_selected) {
                return;
            }

            unowned Gtk.TreeModel mod;
            var paths_list = tree_sel.get_selected_rows (out mod);

            if (paths_list.length () > 0) {
                tree_sel.unselect_path (paths_list.nth_data (0));
            }
        }

        public void scroll_to_current (Gtk.TreeIter iter) {
            tree_sel.unselect_all ();

            var current_path = list_store.get_path (iter);

            if (current_path != null) {
                list_view.set_cursor (current_path, null, false);
            }
        }

        private void on_row_inserted (Gtk.TreePath path, Gtk.TreeIter iter) {
            list_store.row_inserted.disconnect (on_row_inserted);
            set_visible_child_name (view_name);
        }

        public void show_welcome () {
            var welcome_screen = get_child_by_name ("welcome");
            if (welcome_screen != null && visible_child_name != "welcome") {
                set_visible_child (welcome_screen);
            }
        }

        public void show_alert () {
            var alert_view = get_child_by_name ("alert");
            if (alert_view != null && visible_child_name != "alert") {
                if (visible_child_name != "welcome") {
                    view_name = visible_child_name;
                }

                set_visible_child (alert_view);
            }
        }
    }
}
