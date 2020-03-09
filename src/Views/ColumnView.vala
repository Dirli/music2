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
    public class Views.ColumnView : Gtk.TreeView {
        private Enums.Category category;

        public ColumnView (Enums.Category category) {
            this.category = category;
        }

        construct {
            set_headers_clickable (true);
            headers_visible = true;
            activate_on_single_click = false;
            get_selection ().set_mode (Gtk.SelectionMode.SINGLE);

            var tvc = create_column ();
            add_column (tvc);
        }

        public void add_column (Gtk.TreeViewColumn column) {
            column.sizing = Gtk.TreeViewColumnSizing.FIXED;

            bool column_resizable = true;
            var test_strings = new string[0];

            Gtk.CellRenderer? renderer = null;

            switch (category) {
                case Enums.Category.ALBUM:
                case Enums.Category.GENRE:
                case Enums.Category.ARTIST:
                    renderer = new Gtk.CellRendererText ();
                    column.set_cell_data_func (renderer, cell_data_func);
                    test_strings += _("Sample List String");
                    break;
            }

            column.pack_start (renderer, true);
            insert_column (column, -1);

            if (renderer != null) {
                var text_renderer = renderer as Gtk.CellRendererText;
                if (text_renderer != null) {
                    set_fixed_column_width (this, column, text_renderer, test_strings, 5);
                }
            }

            column.reorderable = false;
            column.clickable = true;
            column.resizable = column_resizable;
            column.expand = column_resizable;
            column.sort_indicator = false;

            var header_button = column.get_button ();

            if (headers_visible) {
                Gtk.Requisition natural_size;
                header_button.get_preferred_size (null, out natural_size);

                if (natural_size.width > column.fixed_width) {
                    column.fixed_width = natural_size.width;
                }

                if (column.sort_indicator) {
                    column.fixed_width += 5;
                }
            }

            column.min_width = column.fixed_width;
        }

        private Gtk.TreeViewColumn create_column () {
            var column = new Gtk.TreeViewColumn ();
            column.set_data<int> (Constants.TYPE_DATA_KEY, 0);
            column.title = category.to_string ();
            column.visible = true;

            column.clicked.connect (() => {

            });

            return column;
        }

        private void set_fixed_column_width (Gtk.Widget treeview, Gtk.TreeViewColumn column, Gtk.CellRendererText renderer, string[] strings, int padding) {
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

        private static inline void cell_data_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
            if ((tree_model as Gtk.ListStore).iter_is_valid (iter)) {
                GLib.Value val;
                tree_model.get_value (iter, 0, out val);
                (cell as Gtk.CellRendererText).text = val.get_string ();
            }
        }
    }
}
