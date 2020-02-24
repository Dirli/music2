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

namespace Music2.Enums {
    public enum ViewMode {
        GRID = 0,
        COLUMN = 1;
    }

    public enum SourceType {
        NONE = 0,
        DIRECTORY,
        LIBRARY,
        PLAYLIST,
        QUEUE,
    }

    public enum ActionType {
        NONE = 0,
        PLAY,
        LOAD,
    }

    public enum Hint {
        NONE,
        MUSIC,
        PLAYLIST,
        READ_ONLY_PLAYLIST,
        SMART_PLAYLIST,
        ALBUM_LIST,
        QUEUE;
    }

    public enum ListColumn {
        ICON = 0,
        TRACKID,
        NUMBER,
        TRACK,
        TITLE,
        LENGTH,
        ARTIST,
        ALBUM,
        GENRE,
        YEAR,
        BITRATE,
        N_COLUMNS;

        public string to_string () {
            switch (this) {
                case ICON:
                    return " ";
                case TRACKID:
                    return C_("List column title", "ID");
                case NUMBER:
                    return C_("List column title", "#");
                case TRACK:
                    return C_("List column title", "Track");
                case TITLE:
                    return C_("List column title", "Title");
                case LENGTH:
                    return C_("List column title", "Length");
                case ARTIST:
                    return C_("List column title", "Artist");
                case ALBUM:
                    return C_("List column title", "Album");
                case GENRE:
                    return C_("List column title", "Genre");
                case YEAR:
                    return C_("List column title", "Year");
                case BITRATE:
                    return C_("List column title", "Bitrate");
                default:
                    GLib.assert_not_reached ();
            }
        }

        public Type get_data_type () {
            switch (this) {
                case ICON:
                    return typeof (GLib.Icon);
                case TITLE:
                case ARTIST:
                case ALBUM:
                case GENRE:
                    return typeof (string);
                case TRACKID:
                case NUMBER:
                case LENGTH:
                case TRACK:
                case YEAR:
                case BITRATE:
                    return typeof (uint);
                default:
                    GLib.assert_not_reached ();
            }
        }

        public Value? get_value_for_media (CObjects.Media m, int media_row_index = -1) {
            switch (this) {
                case ICON:
                    return new GLib.ThemedIcon ("audio-volume-high-symbolic");
                case TRACKID:
                    return m.tid;
                case TRACK:
                    return m.track;
                case TITLE:
                    return m.get_display_title ();
                case LENGTH:
                    return m.length;
                case ARTIST:
                    return m.get_display_artist ();
                case ALBUM:
                    return m.get_display_album ();
                case GENRE:
                    return m.get_display_genre ();
                case YEAR:
                    return m.year;
                case BITRATE:
                    return m.bitrate;
            }

            GLib.assert_not_reached ();
        }

        public static GLib.Type[] get_all () {
            GLib.Type[] types = new GLib.Type[] {};

            for (int i = 0; i < N_COLUMNS; i++) {
                types += ((ListColumn) i).get_data_type ();
            }

            return types;
        }
    }

    public enum Category {
        GENRE = 0,
        ARTIST,
        ALBUM,
        N_CATEGORIES;

        public string to_string () {
            switch (this) {
                case Category.GENRE:
                    return _("Genres");
                case Category.ARTIST:
                    return _("Artists");
                case Category.ALBUM:
                    return _("Albums");
                default:
                    GLib.assert_not_reached ();
            }
        }

        public static Category[] get_all () {
            Category[] list = {};
            for (int i = 0; i < N_CATEGORIES; i++) {
                list += (Category) i;
            }

            return list;
        }
    }
}
