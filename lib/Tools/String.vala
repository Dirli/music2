namespace Music2.Tools.String {
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
}
