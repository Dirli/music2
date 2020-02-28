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
    public abstract class Interfaces.GenericList : Gtk.TreeView {
        public Enums.Hint hint {get; construct set;}

        public abstract void add_column (Gtk.TreeViewColumn column);

        construct {
            get_selection ().set_mode (Gtk.SelectionMode.MULTIPLE);
        }


        protected void init_columns () {
            Gee.LinkedList<Gtk.TreeViewColumn> columns = new Gee.LinkedList<Gtk.TreeViewColumn> ();

            columns.add (create_column (Enums.ListColumn.TRACKID, false));

            switch (hint) {
                case Enums.Hint.ALBUM_LIST:
                    columns.add (create_column (Enums.ListColumn.ICON));
                    columns.add (create_column (Enums.ListColumn.TITLE));
                    columns.add (create_column (Enums.ListColumn.LENGTH));
                    columns.add (create_column (Enums.ListColumn.ARTIST, false));
                    break;
                case Enums.Hint.QUEUE:
                default:
                    columns.add (create_column (Enums.ListColumn.ICON));
                    bool num_column_visible = hint == Enums.Hint.PLAYLIST;
                    columns.add (create_column (Enums.ListColumn.TRACK, num_column_visible));
                    columns.add (create_column (Enums.ListColumn.TITLE));
                    columns.add (create_column (Enums.ListColumn.LENGTH));
                    columns.add (create_column (Enums.ListColumn.ARTIST));
                    columns.add (create_column (Enums.ListColumn.ALBUM));
                    break;
            }

            columns.foreach ((column) => {
                add_column (column);
                return true;
            });
        }

        private Gtk.TreeViewColumn create_column (Enums.ListColumn type, bool visible = true) {
            var column = new Gtk.TreeViewColumn ();
            column.set_data<int> (Constants.TYPE_DATA_KEY, type);
            column.title = type.to_string ();
            column.visible = visible;

            column.clicked.connect (() => {
                // sort_direction = column.get_sort_order ();
                // sort_column_id = Tools.CellDataHelper.get_column_type (column);
            });

            return column;
        }

        protected void set_fixed_column_width (Gtk.Widget treeview, Gtk.TreeViewColumn column, Gtk.CellRendererText renderer, string[] strings, int padding) {
            int max_width = 0;

            foreach (unowned string str in strings) {
                renderer.text = str;
                Gtk.Requisition natural_size;
                renderer.get_preferred_size (treeview, null, out natural_size);

                if (natural_size.width > max_width) {
                    max_width = natural_size.width;
                }
            }

            column.fixed_width = max_width + padding;
        }
    }
}
