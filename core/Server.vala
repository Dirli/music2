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
    public class Core.Server : GLib.Object {
        private GLib.Application app;

        private uint owner_id;
        private int queue_id;

        private GLib.Settings settings;
        private Core.Player player;

        private Enums.SourceType? active_source_type = null;

        private CObjects.Scanner? scanner = null;
        private DataBaseManager? db_manager = null;

        public Server (GLib.Application app) {
            this.app = app;
            settings = new GLib.Settings (Constants.APP_NAME);

            player = new Core.Player ();
            player.set_volume (settings.get_double ("volume"));

            init_mpris ();

            player.changed_track.connect (on_changed_track);
            player.changed_volume.connect ((volume_value) => {
                settings.set_double ("volume", volume_value);
            });

            on_changed_repeat ();
            on_changed_shuffle ();

            settings.changed["repeat-mode"].connect (on_changed_repeat);
            settings.changed["shuffle-mode"].connect (on_changed_shuffle);
            settings.changed["source-type"].connect (on_changed_source);
        }

        private void on_changed_track (CObjects.Media m) {
            string notification_body = m.get_display_artist ();
            notification_body += "\n";
            notification_body += m.get_display_album ();

            show_notification (m.get_display_title (),
                               notification_body,
                               Tools.FileUtils.get_cover_path (m.year, m.album));
        }

        private void on_changed_repeat () {
            player.repeat_mode = settings.get_enum ("repeat-mode");
        }

        private void on_changed_shuffle () {
            player.shuffle_mode = settings.get_enum ("shuffle-mode");
        }

        private void on_changed_source () {
            active_source_type = (Enums.SourceType) settings.get_enum ("source-type");
            player.clear_queue ();

            switch (active_source_type) {
                case Enums.SourceType.DIRECTORY:
                    play_from_directory ();
                    break;
                case Enums.SourceType.LIBRARY:
                    play_from_library ();
                    break;
                case Enums.SourceType.NONE:
                    uint[] zero_arr = {};

                    player.current_index = 0;
                    player.tracklist_replaced (zero_arr);

                    if (db_manager != null) {
                        db_manager = null;
                    }

                    break;
            }
        }

        private void on_bus_acquired (DBusConnection connection, string name) {
            try {
                connection.register_object (Constants.MPRIS_PATH, new Core.MprisRoot (this));
                connection.register_object (Constants.MPRIS_PATH, new Core.MprisTrackList (player));
                connection.register_object (Constants.MPRIS_PATH, new Core.MprisPlayer (connection, player));
            } catch (IOError e) {
                warning ("could not create MPRIS player: %s\n", e.message);
                close_player ();
            }
        }

        private void init_mpris () {
            owner_id = GLib.Bus.own_name (GLib.BusType.SESSION,
                                          Constants.MPRIS_NAME,
                                          GLib.BusNameOwnerFlags.NONE,
                                          on_bus_acquired,
                                          null,
                                          null);

            if (owner_id == 0) {
                warning ("Could not initialize MPRIS session.\n");
                close_player ();
            }
        }

        public void init_player () {
            if (active_source_type == null) {
                active_source_type = (Enums.SourceType) settings.get_enum ("source-type");
                player.clear_queue ();
                switch (active_source_type) {
                    case Enums.SourceType.DIRECTORY:
                        play_from_directory ();
                        break;
                    case Enums.SourceType.LIBRARY:
                        if (init_db ()) {
                            var tracks_queue = db_manager.get_playlist_tracks (queue_id);
                            player.adds_to_queue (tracks_queue);
                        }

                        break;
                }
            }
        }

        private bool init_db () {
            if (db_manager == null) {
                db_manager = DataBaseManager.instance;
                if (!db_manager.check_db) {
                    settings.set_enum ("source-type", Enums.SourceType.NONE);
                    return false;
                }
                queue_id = db_manager.get_playlist_id (Constants.QUEUE);
            }

            return true;
        }

        public void close_player () {
            if (!settings.get_boolean ("close-while-playing") && player.get_state () == Gst.State.PLAYING) {
                return;
            }

            GLib.Bus.unown_name (owner_id);

            player.stop ();
            Core.Daemon.on_exit (0);
        }

        private void stop_scanner () {
            scanner.discovered_new_item.disconnect (on_new_item);
            scanner.stop_discovered ();
            scanner = null;
        }

        private void play_from_library () {
            if (!init_db ()) {
                return;
            }

            string[] filter = settings.get_string ("source-media").split ("::");

            Gee.ArrayQueue<CObjects.Media>? tracks_queue = null;
            if (filter.length == 2) {
                tracks_queue = db_manager.get_tracks ((Enums.Category) int.parse (filter[0]),
                                                      filter[1]);
            }

            if (tracks_queue == null) {
                tracks_queue = db_manager.get_tracks (null);
            }

            settings.set_string ("source-media", "");
            player.adds_to_queue (tracks_queue);
            db_manager.update_playlist (queue_id, player.get_queue ());
        }

        private void play_from_directory () {
            if (scanner != null && scanner.launched) {
                stop_scanner ();
            }

            scanner = new CObjects.Scanner ();
            scanner.init ();
            scanner.discovered_new_item.connect (on_new_item);
            scanner.start_scan (settings.get_string ("source-media"));
        }

        private void on_new_item (CObjects.Media? m) {
            if (m != null) {
                player.add_to_queue (m);
                player.added_to_queue (m);
                if (player.current_index == 0 || player.current_index == m.tid) {
                    player.current_index = m.tid;
                }
            }

            if (scanner.stop_scan ()) {
                stop_scanner ();
            }
        }

        private void show_notification (string title,
                                        string body,
                                        string icon_path = "",
                                        GLib.NotificationPriority priority = GLib.NotificationPriority.LOW,
                                        string context = "music2") {

           var notification = new GLib.Notification (title);
           notification.set_body (body);
           notification.set_priority (priority);
           if (icon_path != "") {
               try {
                   notification.set_icon (GLib.Icon.new_for_string (icon_path));
               } catch (Error e) {
                   warning (e.message);
               }
           } else {
               notification.set_icon (new GLib.ThemedIcon ("multimedia-audio-player"));
           }

           app.send_notification (context, notification);
        }
    }
}
