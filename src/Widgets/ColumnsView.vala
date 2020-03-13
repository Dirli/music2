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
    public class Widgets.ColumnsView : Gtk.Grid {
        public signal void filter_list (Enums.Category type, int val);

        private Enums.Category filter_field;
        private int filter_value;

        public ColumnsView () {
            foreach (unowned Enums.Category category in Enums.Category.get_all ()) {
                if (category != Enums.Category.N_CATEGORIES) {
                    add_column (category);
                }
            }
        }

        public void clear_columns (Enums.Category? filter_category) {
            foreach (unowned Enums.Category category in Enums.Category.get_all ()) {
                if (category != Enums.Category.N_CATEGORIES) {
                    if (filter_category == null || (int) filter_category < (int) category) {
                        var column = get_child_at (category, 0);
                        if (column != null) {
                            (column as Views.ColumnBrowser).clear_column ();
                        }
                    }
                }
            }
        }

        public void init_selections (Enums.Category? cat) {
            foreach (unowned Enums.Category category in Enums.Category.get_all ()) {
                if (category != Enums.Category.N_CATEGORIES) {
                    if (cat == null || (int) cat < (int) category) {
                        var column = get_child_at (category, 0);
                        if (column != null) {
                            (column as Views.ColumnBrowser).init_selection ();
                        }
                    }
                }
            }
        }

        protected void add_column (Enums.Category type) {
            var column = new Views.ColumnBrowser (type);
            column.set_size_request (60, 100);
            column.select_row.connect ((val) => {
                filter_field = type;
                filter_value = val;
                filter_list (type, val);
            });

            column.activated_row.connect (() => {

            });

            column.hexpand = column.vexpand = true;
            attach (column, (int) type, 0, 1, 1);
        }

        public Structs.Filter get_filter () {
            Structs.Filter f = {};
            f.field = filter_field;
            f.val = filter_value;

            return f;
        }

        public void add_column_item (Structs.Iter iter) {
            var column = get_child_at (iter.category, 0);
            if (column != null) {
                (column as Views.ColumnBrowser).add_item (iter.name, iter.id);
            }
        }
    }
}
