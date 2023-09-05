namespace Music2 {
    public class Widgets.DnDSelection : Granite.Widgets.Welcome {
        public string[] uris {
            get; private set;
        }

        public DnDSelection () {
            Object (title: _("What To Do With The Source"),
                    subtitle: "");
        }

        construct {
            append ("media-playback-start", _("Play Music"), _("Play music tracks from a source."));
            append ("document-import", _("Import Music"), _("Import music from a source into your library."));
            append ("playlist", _("Add as External Playlist"), _("Create an external playlist from tracks from an external source."));
            append ("pane-hide", _("Return"), _("Cancel drag"));
        }

        public bool add_uris (string[] u) {
            if (u.length > 0) {
                uris = u;
                var f = GLib.File.new_for_uri (u[0]);
                subtitle = f.get_path () ?? "";

                return true;
            }

            return false;
        }

        public void reset () {
            uris = null;
            subtitle = "";
        }
    }
}