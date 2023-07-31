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
        public signal void popup_media_menu (double x_point, double y_point);

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
            var test_strings = new string[0];

            Enums.ListColumn type = Tools.CellDataHelper.get_column_type (column);

            Gtk.CellRenderer? renderer = null;
            if (type == Enums.ListColumn.ICON) {
                var icon_renderer = new Gtk.CellRendererPixbuf () {
                    stock_size = Gtk.IconSize.MENU
                };
                int width, height;
                Gtk.icon_size_lookup ((Gtk.IconSize) icon_renderer.stock_size, out width, out height);

                column.fixed_width = int.max (width, height) + 7;
                column.set_cell_data_func (icon_renderer, Tools.CellDataHelper.icon_func);
                column.pack_start (icon_renderer, true);
            } else if (type == Enums.ListColumn.TRACKID || type == Enums.ListColumn.TRACK) {
                renderer = new Gtk.CellRendererText ();
                column.pack_start (renderer, true);
                column.set_cell_data_func (renderer, Tools.CellDataHelper.intelligent_func);

                test_strings += "9999";
            } else if (type == Enums.ListColumn.LENGTH) {
                renderer = new Gtk.CellRendererText ();
                column.pack_start (renderer, true);
                column.set_cell_data_func (renderer, Tools.CellDataHelper.length_func);

                test_strings += "0000:00";
            } else if (type == Enums.ListColumn.ALBUM || type == Enums.ListColumn.TITLE || type == Enums.ListColumn.ARTIST) {
                renderer = new Gtk.CellRendererText ();
                column.pack_start (renderer, true);
                column.add_attribute (renderer, "text", type);

                test_strings += _("Sample List String");
            }

            insert_column (column, type == Enums.ListColumn.ICON ? type : -1);

            if (renderer != null) {
                var text_renderer = renderer as Gtk.CellRendererText;
                if (text_renderer != null) {
                    set_fixed_column_width (this, column, text_renderer, test_strings, 5);
                }
            }

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
            if ((hint == Enums.Hint.MUSIC && type == Enums.ListColumn.TRACKID)
                || type == Enums.ListColumn.TITLE
                || type == Enums.ListColumn.ICON) {
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
                popup_media_menu (event.x, event.y);
                return true;
            }

            return base.button_press_event (event);
        }
    }
}
