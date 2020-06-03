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
    public class Widgets.ViewStack : Interfaces.StackWrapper {
        construct {
            expand = true;

            alert_view = new Granite.Widgets.AlertView (_("No Results"), _("Try another search"), "edit-find-symbolic");
            add_named (alert_view, "alert");
        }

        public override void clear_stack () {
            show_alert ();
        }

        protected override uint get_selected_tid (Gtk.TreePath filter_path) {
            return 0;
        }
    }
}
