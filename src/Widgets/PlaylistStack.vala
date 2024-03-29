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
    public class Widgets.PlaylistStack : Interfaces.ListStack {
        public bool modified { get; set; default = false; }

        public int pid {
            get;
            private set;
        }

        public PlaylistStack () {
            Object (view_name: "listview");
        }

        construct {
            hint = Enums.Hint.PLAYLIST;
            pid = -1;

            iter_hash = new Gee.HashMap<uint, Gtk.TreeIter?> ();

            add_named (new Granite.Widgets.AlertView (_("No Songs"), "", "dialog-information"), "alert");
            add_named (init_list_view (), "listview");

            list_store = new Gtk.ListStore.newv (Enums.ListColumn.get_all ());
            list_view.set_model (list_store);

            update_visible ();
            show_alert ();
        }

        public void init_store (int p_id, Enums.Hint h) {
            clear_stack ();
            pid = p_id;
            
            if (hint != h) {
                hint = h;
                update_visible ();
            }
        }

        public Gee.ArrayQueue<uint> get_playlist () {
            var tracks = new Gee.ArrayQueue<uint> ();

            list_store.@foreach ((model, path, iter) => {
                uint tid;
                list_store.@get (iter, (int) Enums.ListColumn.TRACKID, out tid, -1);

                tracks.offer (tid);

                return false;
            });

            return tracks;
        }

        public override int add_iter (CObjects.Media m) {
            Mutex mutex = Mutex ();
            mutex.lock ();
            m.track = iter_hash.size + 1;
            Gtk.TreeIter iter;
            list_store.insert_with_values (out iter, -1,
                Enums.ListColumn.TRACKID, m.tid,
                Enums.ListColumn.TRACK, m.track,
                Enums.ListColumn.ALBUM, m.get_display_album (),
                Enums.ListColumn.LENGTH, m.length,
                Enums.ListColumn.TITLE, m.get_display_title (),
                Enums.ListColumn.ARTIST, m.get_display_artist (), -1);
                
            iter_hash[m.tid] = iter;
            mutex.unlock ();

            return 1;
        }

        public override int remove_iter (uint tid) {
            if (iter_hash.has_key (tid)) {
                Gtk.TreeIter iter = iter_hash[tid];

                uint t_number = 0;
                list_store.@get (iter, Enums.ListColumn.TRACK, out t_number, -1);

                list_store.remove (ref iter);
                if (list_store.iter_is_valid (iter)) {
                    list_store.@set (iter, Enums.ListColumn.TRACK, t_number, -1);

                    while (list_store.iter_next (ref iter)) {
                        list_store.@set (iter, Enums.ListColumn.TRACK, ++t_number, -1);
                    }
                }

                iter_hash.unset (tid);

                return 1;
            }

            return 0;
        }

        public override void clear_stack () {
            show_alert ();
            iter_hash.clear ();
            list_store.clear ();
        }

        private void update_visible () {
            var alert_view = (Granite.Widgets.AlertView) get_child_by_name ("alert");
            if (alert_view == null) {
                return;
            }

            alert_view.hide_action ();

            string message_body = "";
            switch (hint) {
                case Enums.Hint.EXTERNAL_PLAYLIST:
                    message_body = _("Loading playlist. Please wait.");
                    break;
                case Enums.Hint.PLAYLIST:
                    message_body = _("To add songs to this playlist, use the <b>secondary click</b> on an item and choose <b>Add to Playlist</b>.");
                    break;
                case Enums.Hint.SMART_PLAYLIST:
                    alert_view.show_action (_("Edit Smart Playlist"));

                    // alert_view.action_activated.connect (() => {
                    //
                    // });

                    message_body = _("This playlist will be automatically populated with songs that match its rules. To modify these rules, use the <b>secondary click</b> on it in the sidebar and click on <b>Edit</b>. Optionally, you can click on the button below.");
                    break;
                case Enums.Hint.NONE:
                    debug ("Hint = NONE");
                    break;
                default:
                    GLib.assert_not_reached ();
            }

            alert_view.description = message_body;
        }
    }
}
