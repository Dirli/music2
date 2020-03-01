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
    public class Widgets.PlaylistStack : Interfaces.StackWrapper {
        public int pid;
        public Enums.Hint playlist_hint;

        construct {
            alert_view = new Granite.Widgets.AlertView ("", "", "");

            iter_hash = new Gee.HashMap<uint, Gtk.TreeIter?> ();

            add_named (alert_view, "alert");
            add_named (init_list_view (Enums.Hint.PLAYLIST), "listview");
        }

        public void init_store (int p_id, Enums.Hint hint, Enums.SourceType type) {
            clear_stack ();
            pid = p_id;
            source_type = type;

            if (playlist_hint != hint) {
                playlist_hint = hint;
                update_visible ();
            }
        }

        public override void clear_stack () {
            show_alert ();
            iter_hash.clear ();
            list_store.clear ();
        }

        private void update_visible () {
            if (visible_child_name != "alert") {
                current_view = visible_child_name;
            }

            string message_head = "";
            string message_body = "";

            switch (playlist_hint) {
                case Enums.Hint.READ_ONLY_PLAYLIST:
                    message_head = _("No Songs");
                    message_body = _("Updating playlist. Please wait.");
                    break;
                case Enums.Hint.PLAYLIST:
                    message_head = _("No Songs");
                    message_body = _("To add songs to this playlist, use the <b>secondary click</b> on an item and choose <b>Add to Playlist</b>.");
                    break;
                case Enums.Hint.SMART_PLAYLIST:
                    alert_view.show_action (_("Edit Smart Playlist"));

                    alert_view.action_activated.connect (() => {
                        // button_clicked (playlist);
                    });

                    message_head = _("No Songs");
                    message_body = _("This playlist will be automatically populated with songs that match its rules. To modify these rules, use the <b>secondary click</b> on it in the sidebar and click on <b>Edit</b>. Optionally, you can click on the button below.");
                    break;
                case Enums.Hint.NONE:
                    debug ("Hint = NONE");
                    break;
                default:
                    GLib.assert_not_reached ();
            }

            alert_view.icon_name = "dialog-information";
            alert_view.title = message_head;
            alert_view.description = message_body;

            show_alert ();
        }

        public void add_iter (CObjects.Media m) {
            GLib.Mutex mutex = GLib.Mutex ();
            mutex.lock ();

            Gtk.TreeIter iter;
            list_store.insert_with_values (out iter, -1,
                Enums.ListColumn.TRACKID, m.tid,
                Enums.ListColumn.TRACK, m.track,
                Enums.ListColumn.LENGTH, m.length,
                Enums.ListColumn.ALBUM, m.album,
                Enums.ListColumn.TITLE, m.title,
                Enums.ListColumn.ARTIST, m.artist);

            iter_hash[m.tid] = iter;

            mutex.unlock ();
        }
    }
}
