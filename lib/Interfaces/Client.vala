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
    [DBus (name="org.freedesktop.DBus.Properties")]
    public interface DbusPropIface : Object {
        public signal void properties_changed (string iface, GLib.HashTable<string, GLib.Variant> changed, string[] invalid);
    }

    [DBus (name="org.mpris.MediaPlayer2")]
    public interface MprisIface : GLib.Object {
        public abstract void quit () throws GLib.Error;
        public abstract void raise () throws GLib.Error;
        public abstract bool can_raise { get; }
        public abstract bool can_quit { get; }
        // public abstract string desktop_entry { owned get; }
    }

    [DBus (name="org.mpris.MediaPlayer2.Player")]
    public interface PlayerIface : MprisIface {
        public abstract bool can_go_next { get; }
        public abstract bool can_go_previous { get; }
        public abstract bool can_play { get; }
        public abstract bool can_pause { get; }
        public abstract string playback_status { owned get; }
        public abstract GLib.HashTable<string, GLib.Variant> metadata { owned get; }
        public abstract int64 position { get; }
        public abstract int64 duration { get; }
        public abstract double volume { get; set; }

        public abstract void next () throws GLib.Error;
        public abstract void previous () throws GLib.Error;
        public abstract void pause () throws GLib.Error;
        public abstract void play_pause () throws GLib.Error;
        public abstract void stop () throws GLib.Error;
        public abstract void play () throws GLib.Error;
        public abstract int64 get_track_position () throws GLib.Error;
        public abstract void seek (int64 seek) throws GLib.Error;
        // public abstract void set_position (uint tid, int64 pos) throws GLib.Error;
    }

    [DBus (name="org.mpris.MediaPlayer2.TrackList")]
    public interface TrackListIface : GLib.Object {
        public signal void track_list_replaced (uint[] tracks, uint current_track);
        public signal void track_added	(GLib.HashTable<string, GLib.Variant> metadata, uint after_tid = 0);
        public signal void track_removed (uint track_id);

        public abstract uint[] tracks { owned get; }

        public abstract void add_track (string uri, uint after, bool current) throws GLib.Error;
        public abstract void remove_track (uint tid) throws GLib.Error;
        public abstract uint[] get_tracklist () throws GLib.Error;
        public abstract void go_to (uint tid) throws GLib.Error;
        public abstract GLib.HashTable<string, GLib.Variant>[] get_tracks_metadata (uint[] tids) throws GLib.Error;
    }
}
