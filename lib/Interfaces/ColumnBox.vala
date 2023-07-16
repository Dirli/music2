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
    public abstract class Interfaces.ColumnBox : Gtk.Box {
        public signal void select_row (Enums.Category cat, string name, int id);
        public signal void activated_row ();

        protected int n_items = 0;

        public abstract bool row_visible (Gtk.TreeModel model, Gtk.TreeIter iter);

        public Enums.Category category { get; construct set; }
        public Gtk.CheckMenuItem menu_item { get; construct set;}

        protected int selected_item = -1;

        protected LViews.ColumnView view;

        protected Gtk.ListStore list_store;
        protected Gtk.TreeModelFilter? list_filter = null;
        protected Gtk.TreeSelection tree_selection;

        construct {
            menu_item = new Gtk.CheckMenuItem.with_label (category.to_string ());

            view = new LViews.ColumnView (category);
            view.row_activated.connect (on_row_activated);

            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.expand = true;
            scrolled.add (view);
            add (scrolled);

            tree_selection = view.get_selection ();
            tree_selection.set_mode (Gtk.SelectionMode.SINGLE);

            show_all ();
        }

        public void set_model (Gtk.ListStore store) {
            list_store = store;
            view.set_model (store);
        }

        public void init_box () {
            GLib.Idle.add (() => {
                list_filter = new Gtk.TreeModelFilter (list_store, null);
                list_filter.set_visible_func (row_visible);
                view.set_model (list_filter);

                init_selection ();

                return false;
            });
        }

        private void init_selection () {
            var first_path = new Gtk.TreePath.first ();
            tree_selection.select_path (first_path);
            selected_item = 0;

            tree_selection.changed.connect (selected_item_changed);
        }

        public void clear_box () {
            clear_selection ();

            view.set_model (list_store);
            list_filter = null;
        }

        private void clear_selection () {
            selected_item = -1;

            tree_selection.changed.disconnect (selected_item_changed);
            tree_selection.unselect_all ();
        }

        public void filter_list () {
            n_items = -1;
            clear_selection ();

            list_filter.refilter ();

            Gtk.TreeIter first_iter;
            bool valid_iter = list_filter.get_iter_first (out first_iter);

            while (valid_iter) {
                ++n_items;
                valid_iter = list_filter.iter_next (ref first_iter);
            }

            var first_path = new Gtk.TreePath.first ();
            list_filter.get_iter (out first_iter, first_path);

            Gtk.TreeIter child_iter;
            list_filter.convert_iter_to_child_iter (out child_iter, first_iter);
            list_store.@set (child_iter, 0, Tools.String.get_first_item_text (category, n_items), -1);

            init_selection ();
        }

        private void selected_item_changed () {
            unowned Gtk.TreeModel temp_model;
            Gtk.TreeIter iter;

            if (tree_selection.get_selected (out temp_model, out iter)) {
                int value_id;
                string value_str;
                temp_model.@get (iter, 0, out value_str, 1, out value_id, -1);
                if (value_id != selected_item) {
                    if (selected_item != -1) {
                        select_row (category, value_str, value_id);
                    }

                    selected_item = value_id;
                }
            }
        }

        protected void on_row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {}
    }
}
