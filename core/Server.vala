namespace Music2 {
    public class Core.Server : GLib.Object {
        private GLib.Application app;

        private Core.Player player;

        private uint owner_id;

        public Server (GLib.Application app) {
            this.app = app;

            player = new Core.Player ();

            init_mpris ();

            player.changed_track.connect (on_changed_track);
        }

        private void on_changed_track (CObjects.Media m) {

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
    }
}
