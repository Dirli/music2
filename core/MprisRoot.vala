/*
 * Copyright (c) 2020 Dirli <litandrej85@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

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
        public string desktop_entry {
            get {return Constants.APP_NAME;}
        }

        public MprisRoot (Core.Server service) {
            this.service = service;
        }

        public void quit () throws GLib.Error {
            service.close_player ();
        }

        public void raise () throws GLib.Error {
            service.run_gui ();
        }
    }
}
