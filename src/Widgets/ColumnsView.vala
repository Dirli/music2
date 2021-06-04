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
        public signal void refilter (Structs.Filter filter);

        private Gee.ArrayList<uint> filter_tracks;

        private Structs.Filter? current_filter;

        private Enums.Category filter_category;

        public ColumnsView () {
            filter_tracks = new Gee.ArrayList<uint> ();
        }

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

                filter_tracks.clear ();

                Structs.Filter f = {};

                f.str = val_str;
                f.id = val_id;
                switch (filter_category) {
                    case Enums.Category.GENRE:
                        f.category = Enums.ListColumn.GENRE;
                        break;
                    case Enums.Category.ARTIST:
                        f.category = Enums.ListColumn.ARTIST;
                        break;
                    case Enums.Category.ALBUM:
                        f.category = Enums.ListColumn.ALBUM;
                        break;

                }

                current_filter = f;
                refilter (f);
            });

            column.activated_row.connect (() => {
                //
            });

            column.hexpand = column.vexpand = true;
            attach (column, (int) column.category, 0, 1, 1);
        }

        public void add_track (uint tid) {
            if (!filter_tracks.contains (tid)) {
                filter_tracks.add (tid);
            }
        }

        public Structs.Filter? get_filter () {
            return current_filter;
        }

        public Gee.ArrayList<uint> get_tracks () {
            return filter_tracks;
        }
    }
}
