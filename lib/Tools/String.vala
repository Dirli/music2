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

namespace Music2.Tools.String {
    public inline string get_simple_display_text (string? text) {
        return !is_empty (text) ? text : Constants.UNKNOWN;
    }

    public inline bool is_empty (string? text, bool check_white_space = true) {
        if (text != null) {
            return check_white_space ? is_white_space (text) : text == "";
        }

        return true;
    }

    public inline int compare (string? a, string? b) {
        return strcmp (a != null ? a.collate_key () : (string) null,
                       b != null ? b.collate_key () : (string) null);
    }

    public inline bool is_white_space (string text) {
        return text.strip ().length == 0;
    }

    private string? locale_to_utf8 (string string_locale) {
        GLib.Error error;
        size_t bytes_read, bytes_written;
        string? string_utf8 = string_locale.locale_to_utf8 (string_locale.length,
                                                            out bytes_read,
                                                            out bytes_written,
                                                            out error);
        if (error != null)
            string_utf8 = null;

        return string_utf8;
    }

    public inline uint64 uint_from_string (string str) {
        const ushort MAX_DIGITS = 18;
        ushort ndigits = 0;

        var result = new StringBuilder ();
        unichar c;

        for (int i = 0; str.get_next_char (ref i, out c) && ndigits < MAX_DIGITS;) {
            if (c.isdigit ()) {
                result.append_unichar (c);
                ndigits++;
            }
        }

        return ndigits == 0 ? 0 : uint64.parse (result.str);
    }

    public string[] get_simple_string_array (string? text) {
        if (text == null) {
            return new string[0];
        }

        string[] array = new string[0];
        array += text;
        return array;
    }

    public inline string get_first_item_text (Enums.Category category, int n_items) {
        string rv = "";

        if (n_items == 1) {
            rv = _("All ") + category.to_string ();
        } else if (n_items > 1) {
            rv = _("All %i ").printf (n_items) + category.to_string ();
        } else {
            rv = _("No ") + category.to_string ();
        }

        return rv;
    }
}
