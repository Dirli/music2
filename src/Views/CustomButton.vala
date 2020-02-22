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
    public class Views.CustomButton : Gtk.Button {
        public CustomButton (string icon_name, string btn_title) {
            Gtk.Image button_image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.DIALOG);
            button_image.use_fallback = true;
            button_image.set_pixel_size (16);
            button_image.halign = Gtk.Align.CENTER;
            button_image.valign = Gtk.Align.CENTER;

            Gtk.Label button_title = new Gtk.Label (btn_title);
            button_title.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
            button_title.halign = Gtk.Align.START;
            button_title.valign = Gtk.Align.CENTER;

            Gtk.Grid button_grid = new Gtk.Grid ();
            button_grid.column_spacing = 10;

            button_grid.attach (button_image, 0, 0);
            button_grid.attach (button_title, 1, 0);

            add (button_grid);
        }
    }
}
