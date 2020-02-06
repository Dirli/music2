namespace Music2 {
    public class Core.Server : GLib.Object {
        private GLib.Application app;

        private Core.Player player;

        public Server (GLib.Application app) {
            this.app = app;

            player = new Core.Player ();

            player.changed_track.connect (on_changed_track);
        }

        private void on_changed_track (CObjects.Media m) {

        }
    }
}
