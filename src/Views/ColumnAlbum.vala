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
    public class Views.ColumnAlbum : Interfaces.ColumnBox {
        private int filter_value = 0;
        private int filter_field = 0;

        public Gee.ArrayList<string> artists_list;

        public Gee.ArrayList<string> get_artists_hash () {
            return artists_list;
        }

        public ColumnAlbum (Enums.Category category) {
            Object (orientation: Gtk.Orientation.HORIZONTAL,
                    category: category);
        }

        public new void filter_list (int val, int field) {
            filter_value = val;
            filter_field = field;
            artists_list = new Gee.ArrayList<string> ();

            var parent_filter = this as Interfaces.ColumnBox;
            if (parent_filter != null) {
                parent_filter.filter_list ();
            }
        }

        public override bool row_visible (Gtk.TreeModel model, Gtk.TreeIter iter) {
            if (filter_value == 0 || filter_field == 0) {
                return true;
            }

            int iter_id;
            model.@get (iter, 1, out iter_id, -1);
            if (iter_id == 0) {
                return true;
            }

            if ((filter_field - 2) == (int) Enums.Category.GENRE) {
                int filter_id;
                string artists_str;
                model.@get (iter, filter_field, out filter_id, Enums.Category.ARTIST + 2, out artists_str, -1);
                bool res = filter_id == filter_value;
                if (res) {
                    foreach (string a_id in artists_str.split (";")) {
                        if (!artists_list.contains (a_id)) {
                            artists_list.add (a_id);
                        }
                    }
                }

                return res;
            } else if (filter_field - 2 == Enums.Category.ARTIST) {
                string artists_str;
                model.@get (iter, filter_field, out artists_str, -1);
                return filter_value.to_string () in artists_str.split (";");
            }

            return true;
        }
    }
}
