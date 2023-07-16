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
    public class Views.ColumnBrowser : Interfaces.ColumnBox {
        public Gee.ArrayList<int>? filter_values = null;

        public ColumnBrowser (Enums.Category category) {
            Object (orientation: Gtk.Orientation.HORIZONTAL,
                    category: category);
        }

        public new void filter_list (Gee.ArrayList<int> filter_vals) {
            filter_values = filter_vals.size == 0 ? null : filter_vals;

            base.filter_list ();
        }

        public override bool row_visible (Gtk.TreeModel model, Gtk.TreeIter iter) {
            if (filter_values == null || filter_values.size == 0) {
                return true;
            }

            int iter_id;
            model.@get (iter, 1, out iter_id, -1);
            if (iter_id == -1) {
                return true;
            }

            return filter_values.contains (iter_id);
        }
    }
}
