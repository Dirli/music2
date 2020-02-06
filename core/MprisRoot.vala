namespace Music2 {
    [DBus (name = "org.mpris.MediaPlayer2")]
    public class Core.MprisRoot : GLib.Object {
        private Core.Server service;

        public bool can_quit {
            get {return true;}
        }
        public bool can_raise {
            get {return true;}
        }
        public bool has_track_list {
            get {return true;}
        }
        public string identity {
            owned get {return "Music2";}
        }
        public string[] supported_mime_types {
            owned get {return Constants.MEDIA_CONTENT_TYPES;}
        }
        public string[] supported_uri_schemes {
            owned get {return {"http", "file", "https", "ftp"};}
        }

        public MprisRoot (Core.Server service) {
            this.service = service;
        }

        public void quit () throws GLib.Error {
            service.close_player ();
        }

        public void raise () throws GLib.Error {
            // 
        }
    }
}
