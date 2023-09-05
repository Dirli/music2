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
    public class Widgets.ViewStack : Gtk.Stack {
        private string current_view = "";

        public ViewStack () {
            Object (expand: true);
        }

        construct {
            add_named (new Granite.Widgets.AlertView (_("No Results"), _("Try another search"), "edit-find-symbolic"), "alert");
        }

        public new void set_visible_child_name (string name) {
            var v_name = get_visible_child_name ();
            if (v_name != null && v_name != name) {
                current_view = v_name;
            }

            base.set_visible_child_name (name);
        }

        public void return_last_page () {
           if (current_view != "") {
               visible_child_name = current_view;
           }
        }
    }
}
