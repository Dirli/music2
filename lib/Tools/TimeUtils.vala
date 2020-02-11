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

namespace Music2.Tools.TimeUtils {
    public inline string pretty_timestamp_from_time (Time dt) {
        return dt.format (_("%m/%e/%Y %l:%M %p"));
    }

    public string pretty_time_from_sec (int64 s) {
        var time_fmt = "";
        var hours_val = s / 3600;
        var sec_rem = s % 3600;
        if (hours_val > 0) {
            time_fmt += "%lld ".printf (hours_val);
            time_fmt += _("h.");
        }
        if (sec_rem > 0) {
            var min_val = sec_rem / 60;
            sec_rem = sec_rem % 60;
            if (min_val > 0) {
                time_fmt += " %lld ".printf (min_val);
                time_fmt += _("m.");
            }
            if (sec_rem > 0) {
                time_fmt += " %lld ".printf (sec_rem);
                time_fmt += _("s.");
            }
        }

        return time_fmt;
    }

    public inline int64 nano_to_mili (int64 nanoseconds) {
        return nanoseconds * Constants.MILI_INV / Constants.NANO_INV;
    }

    public inline int64 micro_to_nano (int64 micro) {
        if (micro == 0) {
            return 0;
        }

        return micro * Constants.NANO_INV / Constants.MICRO_INV;
    }

    public inline int64 nano_to_sec (int64 nanoseconds) {
        if (nanoseconds == 0) {
            return 0;
        }

        return nanoseconds * Constants.SEC_INV / Constants.NANO_INV;
    }

    public inline int64 sec_to_micro (int64 seconds) {
        return seconds * Constants.MICRO_INV / Constants.SEC_INV;
    }

    public inline uint64 sec_to_nano (uint64 seconds) {
        return (uint64) (seconds * Constants.NANO_INV / Constants.SEC_INV);
    }
}
