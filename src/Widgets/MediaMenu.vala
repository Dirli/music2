namespace Music2 {
    public class Widgets.MediaMenu : Gtk.Popover {
        public signal void activate_menu_item (Enums.Hint hint, Enums.ActionType action_type, uint[] tids);

        private uint[] tracks_id;

        public bool active_media {
            set {
                scroll_to_current.sensitive = value;
            }
        }

        private Gtk.Box menu_box;
        private Gtk.ModelButton scroll_to_current;
        private Gtk.ModelButton file_browse;
        private Gtk.ModelButton edit_media;
        private Gtk.ModelButton import_to_library;
        private Gtk.ModelButton queue_media;
        private Gtk.ModelButton remove_media;

        private Gtk.Separator separator1;
        private Gtk.Separator separator2;

        private Enums.Hint? current_hint = null;

        public MediaMenu () {}

        construct {
            tracks_id = {};

            scroll_to_current = new Gtk.ModelButton ();
            scroll_to_current.set_label (_("Scroll to Current Song"));
            scroll_to_current.sensitive = false;
            scroll_to_current.clicked.connect (() => {
                popdown ();
                activate_menu_item (current_hint, Enums.ActionType.SCROLL, tracks_id);
            });

            file_browse = new Gtk.ModelButton ();
            file_browse.set_label (_("Show in File Browser…"));
            file_browse.clicked.connect (() => {
                popdown ();
                activate_menu_item (current_hint, Enums.ActionType.BROWSE, tracks_id);
            });

            edit_media = new Gtk.ModelButton ();
            edit_media.set_label (_("Edit Song Info…"));
            edit_media.clicked.connect (() => {
                popdown ();
                activate_menu_item (current_hint, Enums.ActionType.EDIT, tracks_id);
            });

            queue_media = new Gtk.ModelButton ();
            queue_media.set_label (C_("Action item (verb)", "Queue"));
            queue_media.clicked.connect (() => {
                popdown ();
                activate_menu_item (current_hint, Enums.ActionType.QUEUE, tracks_id);
            });

            remove_media = new Gtk.ModelButton ();
            remove_media.set_label (_("Remove Song…"));
            remove_media.clicked.connect (() => {
                popdown ();
                activate_menu_item (current_hint, Enums.ActionType.REMOVE, tracks_id);
            });

            import_to_library = new Gtk.ModelButton ();
            import_to_library.set_label (_("Import to Library"));
            import_to_library.clicked.connect (() => {
                popdown ();
                activate_menu_item (current_hint, Enums.ActionType.IMPORT, tracks_id);
            });

            menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);

            separator1 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            separator2 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

            menu_box.add (scroll_to_current);
            menu_box.add (separator1);
            menu_box.add (file_browse);
            menu_box.add (edit_media);
            menu_box.add (queue_media);
            menu_box.add (separator2);
            menu_box.add (remove_media);
            menu_box.add (import_to_library);

            add (menu_box);
            show_all ();
        }

        public void popup_media_menu (Enums.Hint hint, uint[] tids, bool show_scroll) {
            tracks_id = tids;

            if (current_hint == null || current_hint != hint) {
                current_hint = hint;

                (menu_box as Gtk.Container).foreach ((exist_item) => {
                    if (exist_item is Gtk.ModelButton) {
                        exist_item.hide ();
                    }
                });

                switch (hint) {
                    case Enums.Hint.ALBUM_LIST:
                        break;
                    case Enums.Hint.MUSIC:
                    case Enums.Hint.PLAYLIST:
                        edit_media.show ();
                        file_browse.show ();
                        queue_media.show ();
                        separator2.show ();
                        remove_media.show ();
                        if (hint == Enums.Hint.MUSIC) {
                            remove_media.set_label (_("Remove from Library…"));
                        }
                        break;
                    case Enums.Hint.SMART_PLAYLIST:
                        edit_media.show ();
                        file_browse.show ();
                        queue_media.show ();
                        break;
                    case Enums.Hint.QUEUE:
                        if (show_scroll) {
                            scroll_to_current.show ();
                            separator1.show ();
                        }
                        file_browse.show ();
                        separator2.show ();
                        remove_media.show ();
                        remove_media.set_label (_("Remove from Queue"));
                        break;
                    case Enums.Hint.READ_ONLY_PLAYLIST:
                    default:
                        file_browse.show ();
                        break;
                }
            }

            popup ();
        }
    }
}
