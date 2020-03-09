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
    public class Widgets.QueueStack : Interfaces.StackWrapper {
        private Gee.ArrayQueue<CObjects.Media?> tracks_queue;

        private bool add_flag = false;
        private int queue_size;

        construct {
            source_type = Enums.SourceType.QUEUE;
            queue_size = 0;

            iter_hash = new Gee.HashMap<uint, Gtk.TreeIter?> ();
            tracks_queue = new Gee.ArrayQueue<CObjects.Media?> ();

            alert_view = new Granite.Widgets.AlertView (_("No songs in Queue"),
                                                        _("To add songs to the queue, use the <b>secondary click</b> on an item and choose <b>Queue</b>. When a song finishes, the queued songs will be played first before the next song in the currently playing list."),
                                                        "dialog-information");

            add_named (alert_view, "alert");
            add_named (init_list_view (Enums.Hint.QUEUE), "listview");

            show_alert ();
        }

        public override void clear_stack () {
            queue_size = 0;
            show_alert ();
            list_store.clear ();
            iter_hash.clear ();
        }

        public int add_iter (CObjects.Media m) {
            tracks_queue.offer (m);

            if (!add_flag) {
                add_flag = true;
                add_iter_sync ();
                add_flag = false;
            }

            return ++queue_size;
        }

        private void add_iter_sync () {
            while (!tracks_queue.is_empty) {
                var m = tracks_queue.poll ();

                Gtk.TreeIter iter;
                list_store.insert_with_values (out iter, iter_hash.size,
                    Enums.ListColumn.TRACKID, m.tid,
                    Enums.ListColumn.TRACK, m.track,
                    Enums.ListColumn.LENGTH, m.length,
                    Enums.ListColumn.ALBUM, m.album,
                    Enums.ListColumn.TITLE, m.title,
                    Enums.ListColumn.ARTIST, m.artist, -1);

                iter_hash[m.tid] = iter;
            }
        }
    }
}
