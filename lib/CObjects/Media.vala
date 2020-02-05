namespace Music2 {
    public class CObjects.Media : GLib.Object {
        public string uri;
        public string title;
        public string album;
        public string artist;
        public string genre;
        public uint tid;
        public uint track;
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
            return get_simple_display_text (artist);
        }

        internal inline string get_simple_display_text (string? text) {
            return !Tools.String.is_empty (text) ? text : Constants.UNKNOWN;
        }

        public inline string get_display_album () {
            return get_simple_display_text (album);
        }

        public inline string get_display_genre () {
            return get_simple_display_text (genre);
        }
    }
}
