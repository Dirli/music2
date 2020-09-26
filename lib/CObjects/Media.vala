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
    public class CObjects.Media {
        public string uri;
        public string title;
        public string album;
        public string artist;
        public string genre;
        public uint tid = 0;
        public uint hits;
        public uint track;
        // milliseconds
        public uint length;
        public uint year;
        public uint bitrate;

        public Media (string uri) {
            this.uri = uri;
        }

        public inline string get_display_title () {
            string title = this.title;
            return !Tools.String.is_empty (title) ? title : get_display_filename ();
        }

        public inline string get_display_filename () {
            var file = GLib.File.new_for_uri (uri);
            string? filename = Tools.String.locale_to_utf8 (file.get_basename () ?? Constants.UNKNOWN);
            return !Tools.String.is_empty (filename) ? filename : Constants.UNKNOWN;
        }

        public inline string get_display_artist () {
            return Tools.String.get_simple_display_text (artist);
        }

        public inline string get_display_album () {
            return Tools.String.get_simple_display_text (album);
        }

        public inline string get_display_genre () {
            return Tools.String.get_simple_display_text (genre);
        }
    }
}
