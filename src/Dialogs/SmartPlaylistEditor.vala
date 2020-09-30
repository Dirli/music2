namespace Music2 {
    public class Dialogs.SmartPlaylistEditor : Gtk.Dialog {


        public SmartPlaylistEditor (Music2.MainWindow main_win) {
            Object (
                border_width: 6,
                deletable: false,
                destroy_with_parent: true,
                resizable: false,
                title: _("Smart playlists editor"),
                transient_for: main_win,
                window_position: Gtk.WindowPosition.CENTER_ON_PARENT
            );

            set_default_response (Gtk.ResponseType.CLOSE);

            var playlists_status = (int8) main_win.settings.get_int ("smart-playlists");
            var smart_playlists_switch = new Gtk.Switch ();
            smart_playlists_switch.halign = Gtk.Align.START;
            smart_playlists_switch.active = (playlists_status & 1) > 0;

            var limit_spin = new Gtk.SpinButton.with_range (0, 500, 25);
            limit_spin.halign = Gtk.Align.END;
            limit_spin.set_width_chars (4);
            limit_spin.sensitive = smart_playlists_switch.active;
            main_win.settings.bind ("auto-length", limit_spin, "value", SettingsBindFlags.DEFAULT);

            var never_played_switch = new Gtk.Switch ();
            never_played_switch.halign = Gtk.Align.START;
            never_played_switch.active = (playlists_status & 2) > 0;
            never_played_switch.sensitive = smart_playlists_switch.active;

            var favorite_switch = new Gtk.Switch ();
            favorite_switch.halign = Gtk.Align.START;
            favorite_switch.active = (playlists_status & 4) > 0;
            favorite_switch.sensitive = smart_playlists_switch.active;

            var recently_played_switch = new Gtk.Switch ();
            recently_played_switch.halign = Gtk.Align.START;
            recently_played_switch.active = (playlists_status & 8) > 0;
            recently_played_switch.sensitive = smart_playlists_switch.active;

            var layout = new Gtk.Grid ();
            layout.column_spacing = 12;
            layout.margin = 6;
            layout.row_spacing = 6;

            layout.attach (Tools.GuiUtils.get_settings_label (_("Enable smart palylists:")), 0, 0);
            layout.attach (smart_playlists_switch, 1, 0);
            layout.attach (Tools.GuiUtils.get_settings_label (_("Limit to:")), 0, 1);
            layout.attach (limit_spin, 1, 1);
            layout.attach (Tools.GuiUtils.get_settings_label (Constants.NEVER_PLAYED), 0, 2);
            layout.attach (never_played_switch, 1, 2);
            layout.attach (Tools.GuiUtils.get_settings_label (Constants.FAVORITE_SONGS), 0, 3);
            layout.attach (favorite_switch, 1, 3);
            layout.attach (Tools.GuiUtils.get_settings_label (Constants.RECENTLY_PLAYED), 0, 4);
            layout.attach (recently_played_switch, 1, 4);

            var content = get_content_area () as Gtk.Box;
            content.add (layout);

            smart_playlists_switch.notify["active"].connect (() => {
                playlists_status ^= 1;
                main_win.settings.set_int ("smart-playlists", (int) playlists_status);
                never_played_switch.sensitive = smart_playlists_switch.active;
                favorite_switch.sensitive = smart_playlists_switch.active;
                recently_played_switch.sensitive = smart_playlists_switch.active;
            });

            never_played_switch.notify["active"].connect (() => {
                playlists_status ^= 2;
                main_win.settings.set_int ("smart-playlists", (int) playlists_status);
            });

            favorite_switch.notify["active"].connect (() => {
                playlists_status ^= 4;
                main_win.settings.set_int ("smart-playlists", (int) playlists_status);
            });

            recently_played_switch.notify["active"].connect (() => {
                playlists_status ^= 8;
                main_win.settings.set_int ("smart-playlists", (int) playlists_status);
            });

            add_button (_("Close"), Gtk.ResponseType.CLOSE);
            response.connect (() => {destroy ();});
        }
    }
}
