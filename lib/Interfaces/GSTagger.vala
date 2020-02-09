namespace Music2 {
    public abstract class Interfaces.GSTagger : GLib.Object {
        public signal void discovered_new_item (CObjects.Media m);

        protected abstract CObjects.Media? create_media (Gst.PbUtils.DiscovererInfo info);
        protected Gst.PbUtils.Discoverer? discoverer;
        protected int total_scan;

        public bool launched = false;

        public void init () {
            try {
                total_scan = 0;
                discoverer = new Gst.PbUtils.Discoverer ((Gst.ClockTime) (5 * Gst.SECOND));
                discoverer.start ();
                discoverer.discovered.connect (discovered);
            } catch (Error e) {
                warning (e.message);
            }
        }

        public void stop_discovered () {
            discoverer.stop ();
            discoverer.discovered.disconnect (discovered);
            total_scan = 0;
        }

        private void discovered (Gst.PbUtils.DiscovererInfo info, Error? err) {
            ++total_scan;
            new Thread<void*> (null, () => {
                string uri = info.get_uri ();
                if (info.get_result () != Gst.PbUtils.DiscovererResult.OK) {
                    if (err != null) {
                        warning ("DISCOVER ERROR: '%d' %s %s\n(%s)", err.code, err.message, info.get_result ().to_string (), uri);
                    }
                } else {
                    var tags = info.get_tags ();
                    if (tags != null) {
                        var m = create_media (info);

                        discovered_new_item (m);
                    }
                }

                info.dispose ();
                return null;
            });
        }

        public void add_discover_uri (string uri) {
            if (!launched) {
                launched = true;
            }

            discoverer.discover_uri_async (uri);
        }
    }
}
