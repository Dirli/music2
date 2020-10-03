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
    public class Views.ScanLibraryAction : Gtk.Box {
        public signal void button_clicked (Gtk.ResponseType response_type);

        public ScanLibraryAction (string box_label) {
            orientation = Gtk.Orientation.VERTICAL;
            spacing = 8;
            margin_top = margin_bottom = 8;
            margin_start = margin_end = 10;

            var scan_btn = new Views.CustomButton ("media-playback-start-symbolic", "Scan now");
            scan_btn.clicked.connect (() => {
                button_clicked (Gtk.ResponseType.OK);
            });

            var cancel_btn = new Views.CustomButton ("pane-hide-symbolic", "Later");
            cancel_btn.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            cancel_btn.clicked.connect (() => {
                button_clicked (Gtk.ResponseType.CLOSE);
            });

            add (new Gtk.Label (box_label));
            add (scan_btn);
            add (cancel_btn);

            show_all ();
        }
    }
}
