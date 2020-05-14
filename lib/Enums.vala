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
        COLUMN = 1
    }

    public enum RepeatMode {
        OFF = 0,
        MEDIA = 1,
        ON = 2
    }

    public enum ShuffleMode {
        OFF = 0,
        ON = 1
    }

    public enum SourceType {
        NONE = 0,
        DIRECTORY,
        LIBRARY,
        PLAYLIST,
        EXTPLAYLIST,
        FILE,
        QUEUE
    }

    public enum ActionType {
        NONE = 0,
        PLAY,
        CLEAR,
        EDIT,
        EXPORT,
        IMPORT,
        QUEUE,
        REMOVE,
        RENAME,
        BROWSE,
        SCROLL,
        SAVE,
        SCAN
    }

    public enum Hint {
        NONE,
        MUSIC,
        PLAYLIST,
        READ_ONLY_PLAYLIST,
        SMART_PLAYLIST,
        ALBUM_LIST,
        QUEUE
    }

    public enum ListColumn {
        ICON = 0,
        TRACKID = 1,
        TRACK = 2,
        TITLE = 3,
        LENGTH = 4,
        ARTIST = 5,
        ALBUM = 6,
        GENRE = 7,
        YEAR = 8,
        BITRATE = 9,
        N_COLUMNS = 10;

        public string to_string () {
            switch (this) {
                case ICON:
                    return " ";
                case TRACKID:
                    return C_("List column title", "ID");
                case TRACK:
                    return C_("List column title", "#");
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
                case LENGTH:
                case TRACK:
                case YEAR:
                case BITRATE:
                    return typeof (uint);
                default:
                    GLib.assert_not_reached ();
            }
        }

        public static GLib.Type[] get_all () {
            GLib.Type[] types = new GLib.Type[] {};

            for (int i = 0; i < N_COLUMNS; i++) {
                types += ((ListColumn) i).get_data_type ();
            }

            return types;
        }
    }

    public enum PresetGains {
        FLAT,
        CLASSICAL,
        CLUB,
        DANCE,
        FULLBASS,
        FULLTREBLE,
        FULLBASETREBLE,
        HEADPHONES,
        LARGEHALL,
        LIVE,
        PARTY,
        POP,
        REGGAE,
        ROCK,
        SOFT,
        SKA,
        SOFTROCK,
        TECHNO,
        N_PRESETS;

        public string to_string () {
            switch (this) {
                case PresetGains.FLAT:
                    return _("Flat");
                case PresetGains.CLASSICAL:
                    return _("Classical");
                case PresetGains.CLUB:
                    return _("Club");
                case PresetGains.DANCE:
                    return _("Dance");
                case PresetGains.FULLBASS:
                    return _("Full Bass");
                case PresetGains.FULLTREBLE:
                    return _("Full Treble");
                case PresetGains.FULLBASETREBLE:
                    return _("Full Bass + Treble");
                case PresetGains.HEADPHONES:
                    return _("Headphones");
                case PresetGains.LARGEHALL:
                    return _("Large Hall");
                case PresetGains.LIVE:
                    return _("Live");
                case PresetGains.PARTY:
                    return _("Party");
                case PresetGains.POP:
                    return _("Pop");
                case PresetGains.REGGAE:
                    return _("Reggae");
                case PresetGains.ROCK:
                    return _("Rock");
                case PresetGains.SOFT:
                    return _("Soft");
                case PresetGains.SKA:
                    return _("Ska");
                case PresetGains.SOFTROCK:
                    return _("Soft Rock");
                case PresetGains.TECHNO:
                    return _("Techno");
                default:
                    GLib.assert_not_reached ();
            }
        }

        public int[] get_gains () {
            switch (this) {
                case PresetGains.FLAT:
                    return {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
                case PresetGains.CLASSICAL:
                    return {0, 0, 0, 0, 0, 0, -40, -40, -40, -50};
                case PresetGains.CLUB:
                    return {0, 0, 20, 30, 30, 30, 20, 0, 0, 0};
                case PresetGains.DANCE:
                    return {50, 35, 10, 0, 0, -30, -40, -40, 0, 0};
                case PresetGains.FULLBASS:
                    return {70, 70, 70, 40, 20, -45, -50, -55, -55, -55};
                case PresetGains.FULLTREBLE:
                    return {-50, -50, -50, -25, 15, 55, 80, 80, 80, 80};
                case PresetGains.FULLBASETREBLE:
                    return {35, 30, 0, -40, -25, 10, 45, 55, 60, 60};
                case PresetGains.HEADPHONES:
                    return {25, 50, 25, -20, 0, -30, -40, -40, 0, 0};
                case PresetGains.LARGEHALL:
                    return {50, 50, 30, 30, 0, -25, -25, -25, 0, 0};
                case PresetGains.LIVE:
                    return {-25, 0, 20, 25, 30, 30, 20, 15, 15, 10};
                case PresetGains.PARTY:
                    return {35, 35, 0, 0, 0, 0, 0, 0, 35, 35};
                case PresetGains.POP:
                    return {-10, 25, 35, 40, 25, -5, -15, -15, -10, -10};
                case PresetGains.REGGAE:
                    return {0, 0, -5, -30, 0, -35, -35, 0, 0, 0};
                case PresetGains.ROCK:
                    return {40, 25, -30, -40, -20, 20, 45, 55, 55, 55};
                case PresetGains.SOFT:
                    return {25, 10, -5, -15, -5, 20, 45, 50, 55, 60};
                case PresetGains.SKA:
                    return {-15, -25, -25, -5, 20, 30, 45, 50, 55, 50};
                case PresetGains.SOFTROCK:
                    return {20, 20, 10, -5, -25, -30, -20, -5, 15, 45};
                case PresetGains.TECHNO:
                    return {40, 30, 0, -30, -25, 0, 40, 50, 50, 45};
                default:
                    GLib.assert_not_reached ();
            }
        }

        public static PresetGains[] get_all () {
            PresetGains[] list = {};
            for (int i = 0; i < N_PRESETS; i++) {
                list += (PresetGains) i;
            }

            return list;
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
