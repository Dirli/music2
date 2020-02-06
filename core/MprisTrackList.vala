namespace Music2 {
    [DBus (name = "org.mpris.MediaPlayer2.TrackList")]
    public class Core.MprisTrackList : GLib.Object {
        public signal void track_list_replaced (uint[] tracks, uint current_track);
        public signal void track_added (GLib.HashTable<string, GLib.Variant> metadata, uint after_tid = 0);
        public signal void track_removed (uint track_id);

        private Core.Player player;

        public uint[] tracks {
            owned get {
                return player.get_queue ();
            }
        }

        public MprisTrackList (Core.Player player) {
            this.player = player;
            player.added_to_queue.connect (on_added_to_queue);
            player.tracklist_replaced.connect (on_tracklist_replaced);
        }

        // missing from the specification
        public uint[] get_tracklist () throws GLib.Error {
            return player.get_queue ();
        }

        public GLib.HashTable<string, GLib.Variant>[] get_tracks_metadata (uint[] tids) throws GLib.Error {
            GLib.HashTable<string, GLib.Variant>[] tracks_arr = {};
            foreach (var tid in tids) {
                var m = player.get_track (tid);
                if (m != null) {
                    var meta = media_to_metadata (m);
                    tracks_arr += meta;
                }
            }

            return tracks_arr;
        }

        public void add_track (string uri, uint after, bool current) throws GLib.Error {}

        public void remove_track (uint tid) throws GLib.Error {}

        public void go_to (uint tid) throws GLib.Error {
            if (tid > 0) {
                player.launch = true;
                player.current_index = tid;
            }
        }

        private void on_added_to_queue (CObjects.Media m) {
            var meta = media_to_metadata (m);
            track_added (meta);
        }

        private void on_tracklist_replaced (uint[] tracks_id) {
            track_list_replaced (tracks_id, player.current_index);
        }

        private HashTable<string, Variant> media_to_metadata (CObjects.Media m) {
            var _metadata = new HashTable<string, Variant> (null, null);

            _metadata.insert ("mpris:trackid", (int64) m.tid);
            _metadata.insert ("mpris:length", (int64) m.length);
            _metadata.insert ("xesam:trackNumber", (int32) m.track);
            _metadata.insert ("music2:year", (uint16) m.year);
            _metadata.insert ("xesam:title", m.get_display_title ());
            _metadata.insert ("xesam:album", m.get_display_album ());
            _metadata.insert ("xesam:artist", Tools.String.get_simple_string_array (m.get_display_artist ()));
            _metadata.insert ("xesam:genre", Tools.String.get_simple_string_array (m.get_display_genre ()));
            _metadata.insert ("xesam:url", m.uri);

            return _metadata;
        }
    }
}
