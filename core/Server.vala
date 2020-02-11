namespace Music2 {
    public class Core.Server : GLib.Object {
        private GLib.Application app;

        private uint owner_id;

        private GLib.Settings settings;
        private Core.Player player;

        private Enums.SourceType? active_source_type = null;

        private CObjects.Scanner? scanner = null;

        public Server (GLib.Application app) {
            this.app = app;
            settings = new GLib.Settings (Constants.APP_NAME);

            player = new Core.Player ();
            player.set_volume (settings.get_double ("volume"));

            init_mpris ();

            player.changed_track.connect (on_changed_track);
            player.changed_volume.connect ((volume_value) => {
                settings.set_double ("volume", volume_value);
            });

            settings.changed["source-type"].connect (on_changed_source);
        }

        private void on_changed_track (CObjects.Media m) {

        }

        private void on_changed_source () {
            active_source_type = (Enums.SourceType) settings.get_enum ("source-type");
            player.clear_queue ();

            switch (active_source_type) {
                case Enums.SourceType.DIRECTORY:
                    play_from_directory ();
                    break;
            }
        }

        private void on_bus_acquired (DBusConnection connection, string name) {
            try {
                connection.register_object (Constants.MPRIS_PATH, new Core.MprisRoot (this));
                connection.register_object (Constants.MPRIS_PATH, new Core.MprisTrackList (player));
                connection.register_object (Constants.MPRIS_PATH, new Core.MprisPlayer (connection, player));
            } catch (IOError e) {
                warning ("could not create MPRIS player: %s\n", e.message);
            }
        }

        private void init_mpris () {
            owner_id = GLib.Bus.own_name (GLib.BusType.SESSION,
                                          Constants.MPRIS_NAME,
                                          GLib.BusNameOwnerFlags.NONE,
                                          on_bus_acquired,
                                          null,
                                          null);

            if (owner_id == 0) {
                warning ("Could not initialize MPRIS session.\n");
            }
        }

        public void close_player () {
            GLib.Bus.unown_name (owner_id);

            player.stop ();
            Core.Daemon.on_exit (0);
        }

        private void stop_scanner () {
            scanner.discovered_new_item.disconnect (on_new_item);
            scanner.stop_discovered ();
            scanner = null;
        }

        private void play_from_directory () {
            if (scanner != null && scanner.launched) {
                stop_scanner ();
            }

            scanner = new CObjects.Scanner ();
            scanner.init ();
            scanner.discovered_new_item.connect (on_new_item);
            scanner.start_scan (settings.get_string ("source-media"));
        }

        private void on_new_item (CObjects.Media? m) {
            if (m != null) {
                player.add_to_queue (m);
                player.added_to_queue (m);
                if (player.current_index == 0 || player.current_index == m.tid) {
                    player.current_index = m.tid;
                }
            }

            if (scanner.stop_scan ()) {
                stop_scanner ();
            }
        }
    }
}
