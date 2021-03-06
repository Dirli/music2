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

namespace Music2.Structs {
    public struct Album {
        public int album_id;
        public string title;
        public string genre;
        public uint year;
        public string artists_id;
        public string artists;
    }

    public struct Playlist {
        public int id;
        public string name;
        public Enums.SourceType type;
        public Gee.ArrayList<uint> tracks;
    }

    public struct Filter {
        public int id;
        public string str;
        public Enums.Category category;
    }

    public struct Iter {
        public Enums.Category category;
        public string name;
        public int id;
    }

    public struct ImportFile {
        public string parents;
        public string uri;
    }
}
