namespace Music2 {
    public class Views.PlayListCategory : Granite.Widgets.SourceList.ExpandableItem,
                                          Granite.Widgets.SourceListSortable {
        public Gtk.MenuItem playlist_new;
        public Gtk.MenuItem smart_playlist_new;
        public Gtk.MenuItem playlist_import;

        private Gtk.Menu playlist_menu;

        public PlayListCategory (string name) {
            Object (name: name);
        }

        construct {
            playlist_new = new Gtk.MenuItem.with_label (_("New Playlist"));
            smart_playlist_new = new Gtk.MenuItem.with_label (_("New Smart Playlist"));
            playlist_import = new Gtk.MenuItem.with_label (_("Import Playlists"));

            playlist_menu = new Gtk.Menu ();
            playlist_menu.append (playlist_new);
            playlist_menu.append (smart_playlist_new);
            playlist_menu.append (playlist_import);
            playlist_menu.show_all ();
        }

        public override Gtk.Menu? get_context_menu () {
            return playlist_menu;
        }

        private bool allow_dnd_sorting () {
            return true;
        }

        private int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
            var item_a = a as Views.SourceListItem;
            var item_b = b as Views.SourceListItem;

            if (item_a == null || item_b == null) {
                return 0;
            }

            if (item_a.hint == Enums.Hint.READ_ONLY_PLAYLIST) {
                if (item_b.hint == Enums.Hint.READ_ONLY_PLAYLIST) {
                    return strcmp (item_a.name.collate_key (), item_b.name.collate_key ());
                }

                return -1;
            }

            if (item_a.hint == Enums.Hint.SMART_PLAYLIST) {
                if (item_b.hint == Enums.Hint.READ_ONLY_PLAYLIST) {
                    return 1;
                }

                if (item_b.hint == Enums.Hint.SMART_PLAYLIST) {
                    return 0;
                }

                if (item_b.hint == Enums.Hint.PLAYLIST) {
                    return -1;
                }
            }

            if (item_a.hint == Enums.Hint.PLAYLIST) {
                if (item_b.hint == Enums.Hint.PLAYLIST) {
                    return 0;
                }

                return 1;
            }

            return 0;
        }
    }
}
