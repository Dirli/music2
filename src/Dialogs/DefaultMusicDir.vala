namespace Music2 {
    public class Dialogs.DefaultMusicDir : Gtk.Dialog {
        public GLib.Settings settings_gui {
            get;
            construct set;
        }

        public DefaultMusicDir (GLib.Settings s) {
            Object (
                title: _("Music Directory"),
                border_width: 12,
                deletable: false,
                destroy_with_parent: true,
                resizable: false,
                width_request: Constants.DIALOG_MIN_WIDTH,
                window_position: Gtk.WindowPosition.CENTER_ON_PARENT,
                settings_gui: s
            );
        }

        construct {
            var question_label = new Gtk.Label (_("You haven't selected a music directory. Select default music directory?"));
            question_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

            var ask_again_label = new Gtk.Label (_("Don't ask again")) {
                halign = Gtk.Align.END,
                hexpand = true
            };
            var ask_again_swicth = new Gtk.Switch () {
                halign = Gtk.Align.START
            };

            settings_gui.bind ("show-default-dialog", ask_again_swicth, "active", GLib.SettingsBindFlags.INVERT_BOOLEAN);

            var layout = new Gtk.Grid () {
                column_spacing = 12,
                halign = Gtk.Align.END,
                row_spacing = 12
            };

            layout.attach (question_label, 0, 0, 2);
            layout.attach (ask_again_label, 0, 1);
            layout.attach (ask_again_swicth, 1, 1);

            get_content_area ().add (layout);

            add_button ("No", Gtk.ResponseType.CANCEL);

            var suggested_button = add_button ("Yes", Gtk.ResponseType.ACCEPT);
            suggested_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

            response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.ACCEPT) {
                    var default_dir = GLib.Environment.get_user_special_dir (GLib.UserDirectory.MUSIC);
                    if (default_dir != null) {
                        settings_gui.set_string ("music-folder", default_dir);
                    }
                }

                destroy ();
            });
        }

    }
}
