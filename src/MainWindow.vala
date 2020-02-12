namespace Music2 {
    public class MainWindow : Gtk.ApplicationWindow {
        private GLib.Settings settings_ui;
        private GLib.Settings settings;

        private PlayerIface? dbus_player = null;
        private TrackListIface? dbus_tracklist = null;
        private DbusPropIface? dbus_prop = null;

        public MainWindow (Gtk.Application application) {
            Object (application: application);
        }

        construct {
            settings = new GLib.Settings (Constants.APP_NAME);
            settings_ui = new GLib.Settings (Constants.APP_NAME + ".ui");

            try {
                dbus_player = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION, Constants.MPRIS_NAME, Constants.MPRIS_PATH);
                dbus_tracklist = GLib.Bus.get_proxy_sync (BusType.SESSION, Constants.MPRIS_NAME, Constants.MPRIS_PATH);
                dbus_tracklist.track_added.connect (on_track_added);
                dbus_tracklist.track_list_replaced.connect (on_track_list_replaced);
                dbus_prop = GLib.Bus.get_proxy_sync (BusType.SESSION, Constants.MPRIS_NAME, Constants.MPRIS_PATH);
                dbus_prop.properties_changed.connect (on_properties_changed);

            } catch (Error e) {
                warning (e.message);
            }
        }

        // dbus signal handler
        private void on_properties_changed (string iface, GLib.HashTable<string, GLib.Variant> changed_prop, string[] invalid) {

        }

        private void on_track_added (GLib.HashTable<string, GLib.Variant> metadata, uint after_tid = 0) {

        }

        private void on_track_list_replaced (uint[] tracks, uint cur_track) {

        }
    }
}
