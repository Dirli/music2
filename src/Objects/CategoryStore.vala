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
    public class Objects.CategoryStore : Gtk.ListStore {
        public Enums.Category category { get; construct; }

        private int n_items = 0;

        private Gtk.TreeIter first_iter;

        public CategoryStore (Enums.Category category, GLib.Type[] types) {
            Object (category: category);

            set_column_types (types);
            set_sort_column_id (0, Gtk.SortType.ASCENDING);
            set_sort_func (0, new_sort_func);
            add_first_element ();

            row_inserted.connect (on_row_inserted);
        }

        private void on_row_inserted () {
            ++n_items;
            update_first_item ();
        }

        public void add_first_element () {
            var first_text = Tools.String.get_first_item_text (category, n_items);
            Gtk.TreeIter tmp_iter;
            insert_with_values (out tmp_iter, -1, 0, first_text, 1, 0, -1);
            first_iter = tmp_iter;
        }

        private void update_first_item () {
            @set (first_iter, 0, Tools.String.get_first_item_text (category, n_items));
        }

        public new void clear () {
            row_inserted.disconnect (on_row_inserted);

            var list_store = this as Gtk.ListStore;
            if (list_store != null) {
                list_store.clear ();
                n_items = 0;
                add_first_element ();
            }

            row_inserted.connect (on_row_inserted);
        }

        private int new_sort_func (Gtk.TreeModel store , Gtk.TreeIter a, Gtk.TreeIter b) {
            string val_first;
            store.@get (first_iter, 0, out val_first, -1);
            string val_a;
            store.@get (a, 0, out val_a, -1);
            string val_b;
            store.@get (b, 0, out val_b, -1);

            // "All" is always the first
            if (val_first == val_a) {return -1;}
            if (val_first == val_b) {return 1;}

            return Tools.String.compare (val_a, val_b);
        }
    }
}
