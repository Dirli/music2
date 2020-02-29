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
    public class Views.OptionChooser : Gtk.EventBox {
        public signal void option_changed (int cur_option);

        protected Gee.ArrayList<Gtk.Image> options { get; set; }
        protected int current_option { get; private set; }

        construct {
            options = new Gee.ArrayList<Gtk.Image> ();
            current_option = 0;
        }

        public void set_option (int index) {
            if (index >= options.size) {
                return;
            }

            current_option = index;
            option_changed (current_option);

            if (get_child () != null) {
                remove (get_child ());
            }

            add (options[index]);
            show_all ();
        }

        public int append_item (string icon_name, string tooltip) {
            var image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.MENU);
            image.tooltip_text = tooltip;
            options.add (image);

            return options.size - 1;
        }

        public override bool button_press_event (Gdk.EventButton event) {
            if (event.type == Gdk.EventType.BUTTON_PRESS) {
                var next = current_option + 1 < options.size ? current_option + 1 : 0;
                set_option (next);
            }

            return true;
        }
    }
}
