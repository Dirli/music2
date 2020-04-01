namespace Music2 {
    public abstract class Interfaces.Scanner : GLib.Object {
        public abstract void start_scan (string uri);

        public signal void finished_scan (int64 scan_time = -1);
        public signal void added_track (CObjects.Media? m = null);
        public signal void total_found (uint total);

        protected bool stop_flag;

        public void stop_scan () {
            stop_flag = true;
        }
    }
}
