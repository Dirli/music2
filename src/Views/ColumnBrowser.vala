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
    public class Views.ColumnBrowser : Gtk.Box {
        public Enums.Category category { get; construct set; }

        public signal void select_row (int val);
        public signal void activated_row ();

        private Gtk.TreeView view;
        private Gtk.ListStore list_store;
        private Gtk.TreeIter? first_iter;
        private Gtk.TreeSelection? tree_selection = null;

        private int n_items = 0;
        private int cur_selected_item = -1;

        public Gtk.CheckMenuItem menu_item { get; construct set;}

        public ColumnBrowser (Enums.Category category) {
            orientation = Gtk.Orientation.HORIZONTAL;
            visible = false;
            this.category = category;

            menu_item = new Gtk.CheckMenuItem.with_label (category.to_string ());

            view = new Gtk.TreeView ();
            view.activate_on_single_click = false;
            list_store = new Gtk.ListStore (2, typeof (string), typeof (int));
            list_store.set_sort_column_id (0, Gtk.SortType.ASCENDING);
            list_store.set_sort_func (0, new_sort_func);
            view.set_model (list_store);

            var cell = new Gtk.CellRendererText ();
            cell.ellipsize = Pango.EllipsizeMode.END;

            var column = new Gtk.TreeViewColumn.with_attributes (category.to_string (), cell);
            column.expand = false;
            column.set_cell_data_func (cell, cell_data_func);
            column.alignment = 0.5f;
            column.set_sort_column_id (0);

            var cell_id = new Gtk.CellRendererText ();
            var column_id = new Gtk.TreeViewColumn.with_attributes ("id", cell_id);
            column_id.expand = false;
            column_id.set_cell_data_func (cell_id, cell_id_func);
            column_id.visible = false;
            column_id.alignment = 0.5f;

            view.insert_column (column, 0);
            view.insert_column (column_id, 1);
            view.row_activated.connect (on_row_activated);

            column.sort_indicator = false;
            column.clickable = false;

            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.expand = true;
            scrolled.add (view);
            add (scrolled);

            add_first_element ();
        }

        public void clear_column () {
            n_items = 0;
            first_iter = null;
            list_store.clear ();
            cur_selected_item = -1;

            if (tree_selection != null) {
                tree_selection.changed.disconnect (selected_item_changed);
                tree_selection.unselect_all ();
                tree_selection = null;
            }

            add_first_element ();
        }

        public int new_sort_func (Gtk.TreeModel store , Gtk.TreeIter a, Gtk.TreeIter b) {
            if (!list_store.iter_is_valid (a) || !list_store.iter_is_valid (b)) {
                return 0;
            }

            int rv = 1;

            int sort_column_id;
            Gtk.SortType sort_direction;
            list_store.get_sort_column_id (out sort_column_id, out sort_direction);

            if (sort_column_id < 0) {
                return 0;
            }

            if (sort_column_id == 0) {
                // "All" is always the first
                GLib.Value val_first;
                list_store.get_value (first_iter, 0, out val_first);
                string first_str = val_first.get_string ();

                GLib.Value val_a;
                list_store.get_value (a, 0, out val_a);
                string a_str = val_a.get_string ();

                GLib.Value val_b;
                list_store.get_value (b, 0, out val_b);
                string b_str = val_b.get_string ();

                if (a_str == first_str) {
                    rv = -1;
                } else if (b_str == first_str) {
                    rv = 1;
                } else {
                    rv = Tools.String.compare (a_str, b_str);
                }
            }

            if (sort_direction == Gtk.SortType.DESCENDING) {
                rv = (rv > 0) ? -1 : 1;
            }

            return rv;
        }

        public void add_item (string text, int item_id) {
            if (text != "") {
                GLib.Mutex mutex = GLib.Mutex ();
                mutex.lock ();

                Gtk.TreeIter iter;
                list_store.insert_with_values (out iter, -1,
                                               0, text,
                                               1, item_id);

               ++n_items;
               update_first_item ();

               mutex.unlock ();
            }
        }

        private void selected_item_changed () {
            if (tree_selection != null) {
                Gtk.TreeModel temp_model;
                Gtk.TreeIter iter;
                int id_value;

                if (tree_selection.get_selected (out temp_model, out iter)) {
                    temp_model.get (iter, 1, out id_value);
                    if (id_value != cur_selected_item) {
                        if (cur_selected_item != -1) {
                            select_row (id_value);
                        }
                        cur_selected_item = id_value;
                    }
                }
            }
        }

        private void on_row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {

        }

        public void init_selection () {
            GLib.Idle.add (() => {
                tree_selection = view.get_selection ();
                tree_selection.select_iter (first_iter);
                cur_selected_item = 0;

                tree_selection.changed.connect (selected_item_changed);

                return false;
            });
        }

        private void add_first_element () {
            first_iter = Gtk.TreeIter ();
            var first_text = get_first_item_text ();

            list_store.append (out first_iter);
            list_store.set (first_iter, 0, first_text, 1, 0, -1);
        }

        private void update_first_item () {
            list_store.set (first_iter, 0, get_first_item_text ());
        }

        private string get_first_item_text () {
            string rv = "";

            switch (category) {
                case Enums.Category.GENRE:
                    if (n_items == 1) {
                        rv = _("All Genres");
                    } else if (n_items > 1) {
                        rv = _("All %i Genres").printf (n_items);
                    } else {
                        rv = _("No Genres");
                    }
                    break;
                case Enums.Category.ARTIST:
                    if (n_items == 1) {
                        rv = _ ("All Artists");
                    } else if (n_items > 1) {
                        rv = _ ("All %i Artists").printf (n_items);
                    } else {
                        rv = _("No Artists");
                    }
                    break;
                case Enums.Category.ALBUM:
                    if (n_items == 1) {
                        rv = _("All Albums");
                    } else if (n_items > 1) {
                        rv = _("All %i Albums").printf (n_items);
                    } else {
                        rv = _("No Albums");
                    }
                    break;
            }

            return rv;
        }

        public void cell_id_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel model, Gtk.TreeIter iter) {
            if (list_store.iter_is_valid (iter)) {
                var tvc = layout as Gtk.TreeViewColumn;
                GLib.return_if_fail (tvc != null);

                int column = tvc.sort_column_id;
                if (column < 0) {
                    return;
                }

                GLib.Value val;
                model.get_value (iter, column, out val);
                var id = val.get_int ();
                (cell as Gtk.CellRendererText).text = id > 0 ? id.to_string () : "";
            }
        }

        public void cell_data_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
            if (list_store.iter_is_valid (iter)) {
                var tvc = layout as Gtk.TreeViewColumn;
                GLib.return_if_fail (tvc != null);

                int column = tvc.sort_column_id;
                if (column < 0) {
                    return;
                }

                Value val;
                tree_model.get_value (iter, column, out val);
                (cell as Gtk.CellRendererText).text = val.get_string ();
            }
        }
    }
}
