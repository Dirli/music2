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

namespace Music2.Tools.GuiUtils {
    public GLib.Icon? get_cover_icon (uint a_year, string a_title) {
        string cov_path = Tools.FileUtils.get_cover_path (a_year, a_title);
        if (cov_path != "") {
            var cover_file = GLib.File.new_for_path (cov_path);
            if (cover_file.query_exists ()) {
                return new GLib.FileIcon (cover_file);
            }
        }

        return null;
    }

    public Gdk.Pixbuf? get_cover_pixbuf (uint a_year, string? a_title, int scale) {
        if (a_title != null) {
            var cover_icon = get_cover_icon (a_year, a_title);

            if (cover_icon != null) {
                var icon_info = Gtk.IconTheme.get_default ().lookup_by_gicon_for_scale (cover_icon, 128, scale, 0);
                Gdk.Pixbuf? cover_pixbuf = null;

                try {
                    cover_pixbuf = icon_info.load_icon ();
                } catch (Error e) {
                    warning (e.message);
                    return null;
                }

                return cover_pixbuf;
            }
        }

        return null;
    }
}
