namespace Music2 {
    public class Core.Daemon : GLib.Application {
        private static Daemon? instance = null;

        public static unowned Daemon get_instance () {
            if (instance == null) {
                instance = new Daemon ();
            }

            return instance;
        }

        private Daemon () {}

        construct {
            application_id = "io.elementary.music2d";
        }

        public override void activate () {
            new Core.Server (this);
            hold ();
        }

        public static void on_exit (int signum) {
            GLib.Application.get_default ().release ();
        }
    }
}

public static int main (string [] args) {
    Gst.init (ref args);
    GLib.Process.signal (GLib.ProcessSignal.INT, Music2.Core.Daemon.on_exit);
    GLib.Process.signal (GLib.ProcessSignal.TERM, Music2.Core.Daemon.on_exit);
    return Music2.Core.Daemon.get_instance ().run (args);
}
