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
    public class Views.AlbumImage : Gtk.Grid {
        public Gtk.Image image;

        construct {
            var style_context = get_style_context ();
            style_context.add_class (Granite.STYLE_CLASS_CARD);
            style_context.add_class ("album");

            image = new Gtk.Image ();
            image.height_request = 64;
            image.width_request = 64;

            halign = Gtk.Align.CENTER;
            valign = Gtk.Align.CENTER;
            margin = 12;
            add (image);
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void get_preferred_height_for_width (int width, out int minimum_height, out int natural_height) {
            minimum_height = natural_height = width;
            image.pixel_size = width;
        }
    }
}
