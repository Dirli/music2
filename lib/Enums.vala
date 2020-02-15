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
    public enum SourceType {
        NONE = 0,
        DIRECTORY,
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
}
