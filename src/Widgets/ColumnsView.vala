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
        public signal void filter_list (Enums.Category type, string val, int val_id);

        private Enums.Category filter_category;
        private int filter_id;
        private string filter_str;

        public ColumnsView () {}

        public void clear_columns (Enums.Category? filter_category) {
            foreach (unowned Enums.Category category in Enums.Category.get_all ()) {
                if (category != Enums.Category.N_CATEGORIES) {
                    if (filter_category == null || (int) filter_category < (int) category) {
                        var column = get_child_at (category, 0);
                        if (column != null) {
                            var column_browser = column as Interfaces.ColumnBox;
                            if (column_browser != null) {
                                column_browser.clear_box ();
                            }
                        }
                    }
                }
            }
        }

        public void add_column (Interfaces.ColumnBox column) {
            column.set_size_request (60, 100);
            column.select_row.connect ((val_str, val_id) => {
                filter_category = column.category;
                filter_id = val_id;
                filter_str = val_str;
                if (column.category != Enums.Category.ALBUM) {
                    var child_column1 = get_child_at (Enums.Category.ALBUM, 0);
                    if (child_column1 != null) {
                        var column_album = child_column1 as Views.ColumnAlbum;
                        if (column_album != null) {
                            column_album.filter_list (val_id, (int) column.category + 2);
                            if (column.category == Enums.Category.GENRE) {
                                var child_column2 = get_child_at (Enums.Category.ARTIST, 0);
                                if (child_column2 != null) {
                                    var column_browser = child_column2 as Views.ColumnBrowser;
                                    if (column_browser != null) {
                                        var artists_list = column_album.get_artists_hash ();
                                        column_browser.filter_list (artists_list);
                                    }
                                }
                            }
                        }
                    }
                }

                filter_list (column.category, val_id > 0 ? val_str : "", val_id);
            });

            column.activated_row.connect (() => {
                //
            });

            column.hexpand = column.vexpand = true;
            attach (column, (int) column.category, 0, 1, 1);
        }

        public Structs.Filter get_filter () {
            Structs.Filter f = {};
            f.category = filter_category;
            f.id = filter_id;
            f.str = filter_str;

            return f;
        }
    }
}
