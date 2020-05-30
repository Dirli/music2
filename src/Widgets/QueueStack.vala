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
    public class Widgets.QueueStack : Interfaces.ListStack {
        private int queue_size;

        construct {
            source_type = Enums.SourceType.QUEUE;
            queue_size = 0;

            iter_hash = new Gee.HashMap<uint, Gtk.TreeIter?> ();
            list_store = new Gtk.ListStore.newv (Enums.ListColumn.get_all ());

            alert_view = new Granite.Widgets.AlertView (_("No songs in Queue"),
                                                        _("To add songs to the queue, use the <b>secondary click</b> on an item and choose <b>Queue</b>. When a song finishes, the queued songs will be played first before the next song in the currently playing list."),
                                                        "dialog-information");

            add_named (alert_view, "alert");
            add_named (init_list_view (Enums.Hint.QUEUE, list_store), "listview");

            show_alert ();
        }

        public override int add_iter (CObjects.Media m) {
            Gtk.TreeIter iter;
            list_store.insert_with_values (out iter, -1,
                (int) Enums.ListColumn.TRACKID, m.tid,
                (int) Enums.ListColumn.TRACK, m.track,
                (int) Enums.ListColumn.ALBUM, m.get_display_album (),
                (int) Enums.ListColumn.LENGTH, m.length,
                (int) Enums.ListColumn.TITLE, m.get_display_title (),
                (int) Enums.ListColumn.ARTIST, m.get_display_artist (), -1);

            iter_hash[m.tid] = iter;

            return ++queue_size;
        }

        public override int remove_iter (uint tid) {
            if (iter_hash.has_key (tid)) {
                Gtk.TreeIter iter = iter_hash[tid];
                list_store.remove (ref iter);
                iter_hash.unset (tid);
                if (queue_size > 0) {
                    --queue_size;
                }
            }

            return queue_size;
        }

        public bool exist_iter (uint tid) {
            return iter_hash.has_key (tid);
        }

        public override void clear_stack () {
            queue_size = 0;
            show_alert ();
            list_store.clear ();
            iter_hash.clear ();
        }
    }
}
