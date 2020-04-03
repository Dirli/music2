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
    public class LViews.ListView : Interfaces.GenericList {
        public signal void selected_row (uint row_id);
        public signal void popup_media_menu (Enums.Hint hint, double x_point, double y_point, Gtk.Widget w);

        protected Gtk.Menu column_chooser_menu;
        private Gtk.MenuItem autosize_menu_item;

        public ListView (Enums.Hint hint) {
            Object (hint: hint,
                    activate_on_single_click: false);
        }

        construct {
            set_headers_clickable (true);
            headers_visible = true;

            init_columns ();
            show_all ();
        }

        public override void add_column (Gtk.TreeViewColumn column) {
            column.sizing = Gtk.TreeViewColumnSizing.FIXED;

            bool column_resizable = true;
            int column_width = -1;
            int insert_index = -1;
            var test_strings = new string[0];

            Gtk.CellRenderer? renderer = null;
            Enums.ListColumn type = Tools.CellDataHelper.get_column_type (column);

            switch (type) {
                case Enums.ListColumn.ICON:
                    insert_index = type;
                    column_resizable = false;
                    var icon_renderer = new Gtk.CellRendererPixbuf ();
                    icon_renderer.stock_size = Gtk.IconSize.MENU;
                    int width, height;
                    Gtk.icon_size_lookup ((Gtk.IconSize) icon_renderer.stock_size, out width, out height);
                    column_width = int.max (width, height) + 7;
                    column.set_cell_data_func (icon_renderer, Tools.CellDataHelper.icon_func);
                    renderer = icon_renderer;
                    break;
                case Enums.ListColumn.TRACKID:
                case Enums.ListColumn.TRACK:
                    renderer = new Gtk.CellRendererText ();
                    column.set_cell_data_func (renderer, Tools.CellDataHelper.intelligent_func);
                    column_resizable = false;
                    test_strings += "9999";
                    break;
                case Enums.ListColumn.LENGTH:
                    renderer = new Gtk.CellRendererText ();
                    column.set_cell_data_func (renderer, Tools.CellDataHelper.length_func);
                    column_resizable = false;
                    test_strings += "0000:00";
                    break;
                case Enums.ListColumn.ALBUM:
                case Enums.ListColumn.TITLE:
                case Enums.ListColumn.ARTIST:
                    renderer = new Gtk.CellRendererText ();
                    column.set_cell_data_func (renderer, Tools.CellDataHelper.string_func);
                    test_strings += _("Sample List String");
                    break;
                default:
                    GLib.return_if_reached ();
            }

            column.pack_start (renderer, true);
            insert_column (column, insert_index);

            if (column_width > 0) {
                column.fixed_width = column_width;
            } else if (renderer != null) {
                var text_renderer = renderer as Gtk.CellRendererText;
                if (text_renderer != null) {
                    set_fixed_column_width (this, column, text_renderer, test_strings, 5);
                }
            }

            bool sortable = type != Enums.ListColumn.TRACKID && type != Enums.ListColumn.ICON;
            column.reorderable = false;
            column.clickable = true;
            column.resizable = column_resizable;
            column.expand = column_resizable;
            column.sort_column_id = sortable ? (int) type : -1;
            column.sort_indicator = sortable;

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

            add_column_chooser_menu_item (column, type);

            // if (type == Enums.ListColumn.ICON) {
            //     header_button.button_press_event.connect ((e) => {
            //         return view_header_click (e, true);
            //     });
            // } else {
                header_button.button_press_event.connect ((e) => {
                    return view_header_click (e, false);
                });
            // }
        }

        private void add_column_chooser_menu_item (Gtk.TreeViewColumn tvc, Enums.ListColumn type) {
            if (type == Enums.ListColumn.TITLE || type == Enums.ListColumn.ICON) {
                return;
            }
            if (hint == Enums.Hint.MUSIC && type == Enums.ListColumn.TRACKID) {
                return;
            }

            if (column_chooser_menu == null) {
                autosize_menu_item = new Gtk.MenuItem.with_label (_("Autosize Columns"));
                autosize_menu_item.activate.connect (columns_autosize);
                column_chooser_menu = new Gtk.Menu ();
                column_chooser_menu.append (autosize_menu_item);
                column_chooser_menu.append (new Gtk.SeparatorMenuItem ());
                column_chooser_menu.show_all ();
            }
            var menu_item = new Gtk.CheckMenuItem.with_label (tvc.title);
            menu_item.active = tvc.visible;
            column_chooser_menu.append (menu_item);
            column_chooser_menu.show_all ();

            menu_item.toggled.connect (() => {
                tvc.visible = menu_item.active;
                columns_autosize ();
            });
        }

        private new void columns_autosize () {
            foreach (var column in get_columns ()) {
                if (column.min_width > 0) {
                    column.fixed_width = column.min_width;
                }
            }

            base.columns_autosize ();
        }

        private bool view_header_click (Gdk.EventButton e, bool is_selector_col) {
            if (e.button == Gdk.BUTTON_SECONDARY || is_selector_col) {
                column_chooser_menu.popup_at_pointer (e);
                return true;
            }

            return false;
        }

        public override bool button_press_event (Gdk.EventButton event) {
            if (event.window != get_bin_window ()) {
                return base.button_press_event (event);
            }

            if (event.button == Gdk.BUTTON_SECONDARY) {
                popup_media_menu (hint, event.x, event.y, this);
                return true;
            }

            return base.button_press_event (event);
        }
    }
}
