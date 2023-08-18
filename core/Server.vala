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
    [DBus (name = "org.freedesktop.ScreenSaver")]
    public interface ScreenSaverIface : Object {
        public abstract uint32 Inhibit (string app_name, string reason) throws Error;
        public abstract void UnInhibit (uint32 cookie) throws Error;
        public abstract void SimulateUserActivity () throws Error;
    }

    public class Core.Server : GLib.Object {
        private GLib.Application app;

        private uint owner_id;
        private uint write_id = 0;

        private string playlist_path;
        private string tmp_path;

        private GLib.Settings settings;
        private GLib.Settings eq_settings;
        private Core.Player player;
        private Core.Equalizer eq;

        private GLib.FileMonitor tmp_monitor;

        private CObjects.Scanner? scanner = null;
        private ScreenSaverIface? scrsaver_iface = null;

        private uint32? inhibit_cookie = null;

        public Server (GLib.Application app) {
            this.app = app;
            settings = new GLib.Settings (Constants.APP_NAME);
            eq_settings = new GLib.Settings (Constants.APP_NAME + ".equalizer");

            Tools.FileUtils.get_cache_directory ();

            playlist_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S, GLib.Environment.get_user_cache_dir (), Constants.APP_NAME, "cpl");
            tmp_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S, GLib.Environment.get_tmp_dir (), Constants.APP_NAME, "cpl");

            eq = new Core.Equalizer ();
            player = new Core.Player (eq.element);
            player.set_volume (settings.get_double ("volume"));

            on_changed_repeat ();
            on_changed_shuffle ();
            on_changed_sleep ();

            on_selected_preset ();
            on_equalizer_enabled ();

            settings.changed["repeat-mode"].connect (on_changed_repeat);
            settings.changed["shuffle-mode"].connect (on_changed_shuffle);
            settings.changed["block-sleep-mode"].connect (on_changed_sleep);

            eq_settings.changed["selected-preset"].connect (on_selected_preset);
            eq_settings.changed["equalizer-enabled"].connect (on_equalizer_enabled);

            init_mpris ();

            player.changed_track.connect (on_changed_track);
            // player.removed_from_queue.connect (on_removed_from_queue);
            player.changed_volume.connect ((volume_value) => {
                settings.set_double ("volume", volume_value);
            });
            
            init_player ();
        }

        private void on_changed_track (CObjects.Media m, bool run_track) {
            settings.set_uint64 ("current-media", m.tid);

            if (!run_track) {
                return;
            }

            string notification_body = m.get_display_artist ();
            notification_body += "\n";
            notification_body += m.get_display_album ();

            // if (active_source_type == Enums.SourceType.PLAYLIST || active_source_type == Enums.SourceType.LIBRARY) {
            //     var uri = m.uri;
            //     new Thread<void*> ("update_playback_info", () => {
            //         var db_manager = DataBaseManager.to_write ();
            //         if (db_manager != null) {
            //             db_manager.update_playback_info (uri, !settings.get_boolean ("shuffle-mode"));
            //         }
            //
            //         return null;
            //     });
            // }

            var cover_path = "";
            if (m.album != null) {
                cover_path = Tools.FileUtils.get_cover_path (m.year, m.get_display_album ());
            }

            show_notification (m.get_display_title (),
                               notification_body,
                               cover_path);
        }

        // private void on_try_add (string uri) {
        //     if (active_source_type == Enums.SourceType.LIBRARY || active_source_type == Enums.SourceType.PLAYLIST) {
        //         var db_manager = DataBaseManager.to_read ();
        //         if (db_manager == null) {
        //             return;
        //         }
        //
        //         var m = db_manager.get_track (uri);
        //         if (m != null) {
        //             if (player.add_to_queue (m)) {
        //                 player.added_to_queue (m);
        //                 queue_for_write += m.tid;
        //
        //                 if (write_id == 0) {
        //                     write_id = GLib.Timeout.add_seconds (240, write_to_db);
        //                 }
        //             }
        //         }
        //     }
        // }

        // private void on_removed_from_queue (uint tid) {
        //     if (tid > 0) {
        //         new Thread<void*> ("remove_from _queue", () => {
        //             var db_manager = DataBaseManager.to_write ();
        //             if (db_manager != null) {
        //                 db_manager.remove_from_playlist (queue_id, tid);
        //             }
        //
        //             return null;
        //         });
        //     }
        // }

        private void on_changed_repeat () {
            player.repeat_mode = settings.get_enum ("repeat-mode");
        }

        private void on_changed_shuffle () {
            player.shuffle_mode = settings.get_boolean ("shuffle-mode");
        }

        private void on_changed_state () {
            if (player.get_state () == Gst.State.PLAYING) {
                inhibit ();
            } else {
                uninhibit ();
            }
        }

        private void on_changed_sleep () {
            if (settings.get_boolean ("block-sleep-mode")) {
                if (scrsaver_iface == null) {
                    try {
                        scrsaver_iface = GLib.Bus.get_proxy_sync (BusType.SESSION,
                                                                  "org.freedesktop.ScreenSaver",
                                                                  "/ScreenSaver",
                                                                  DBusProxyFlags.NONE);

                        player.changed_state.connect (on_changed_state);
                    } catch (Error e) {
                        warning ("Could not start screensaver interface: %s", e.message);
                    }
                }
            } else {
                player.changed_state.disconnect (on_changed_state);

                uninhibit ();
                scrsaver_iface = null;
            }
        }

        private void on_equalizer_enabled () {
            if (eq_settings.get_boolean ("equalizer-enabled")) {
                player.enable_equalizer ();
            } else {
                player.disable_equalizer ();
            }
        }

        private void on_selected_preset () {
            var selected_preset = eq_settings.get_string ("selected-preset");
            if (selected_preset == "") {
                int i = 0;
                while (i < 10) {
                    eq.set_gain (i++, 0.0);
                }
            } else {
                int[] gains_arr = {};

                foreach (unowned Enums.PresetGains preset_gains in Enums.PresetGains.get_all ()) {
                    if (preset_gains.to_string () == selected_preset) {
                        gains_arr = preset_gains.get_gains ();
                        break;
                    }
                }

                if (gains_arr.length == 0) {
                    string[] custom_presets = eq_settings.get_strv ("custom-presets");

                    for (int i = 0; i < custom_presets.length; i++) {
                        var vals = custom_presets[i].split ("/", 0);

                        if (vals[0] == selected_preset) {
                            for (int j = 1; j < vals.length; j++) {
                                gains_arr += int.parse (vals[j]);
                            }
                            break;
                        }
                    }
                }

                if (gains_arr.length > 0) {
                    int gain_i = 0;
                    foreach (var gain in gains_arr) {
                        eq.set_gain (gain_i++, (double) gain);
                    }
                }
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
            var playlist_file = GLib.File.new_for_path (playlist_path);
            if (playlist_file.query_exists ()) {
                start_scanner (read_playlist (playlist_file, false), false);
            }

            try {
                var tmp_playlist = GLib.File.new_for_path (tmp_path);
                tmp_monitor = tmp_playlist.monitor (GLib.FileMonitorFlags.NONE, null);
                tmp_monitor.changed.connect ((f1, f2, e) => {
                    switch (e) {
                        case GLib.FileMonitorEvent.CHANGES_DONE_HINT:
                            load_new_playlist ();
                            break;
                        case GLib.FileMonitorEvent.DELETED:
                            //
                            break;
                        default:
                            //
                            break;
                    }
                });
            } catch (Error e) {
                warning (e.message);
            }
        }

        public void run_gui () {
            var app_info = new GLib.DesktopAppInfo (Constants.APP_NAME + ".desktop");
            if (app_info == null) {return;}

            try {
                app_info.launch (null, null);
            } catch (Error e) {
                warning (@"Unable to launch $(Constants.APP_NAME): $(e.message)");
            }
        }

        public void close_player () {
            if (!settings.get_boolean ("close-while-playing") && player.get_state () == Gst.State.PLAYING) {
                return;
            }

            if (write_id > 0) {
                GLib.Source.remove (write_id);
            }

            GLib.Bus.unown_name (owner_id);

            tmp_monitor.cancel ();
            player.stop ();

            var files = player.get_uris_queue ();
            string to_save = Tools.FileUtils.files_to_str (files);

            if (to_save != "") {
                Tools.FileUtils.save_playlist (to_save, playlist_path);
            }

            Core.Daemon.on_exit (0);
        }

        public void open_files (GLib.File[] files) {
            settings.set_uint64 ("current-media", 0);

            player.clear_queue ();

            var uris = new Gee.ArrayList<string> ();
            foreach (GLib.File f in files) {
                try {
                    if (!f.query_exists ()
                     || !Tools.FileUtils.is_audio_file (f.query_info ("standard::*," + GLib.FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NONE))) {
                        continue;
                    }

                    uris.add (f.get_uri ());
                } catch (Error e) {
                    warning (e.message);
                }
            }

            if (uris.size > 0) {
                start_scanner (uris, true);
            }
        }

        private void load_new_playlist () {
            player.clear_queue ();

            var new_playlist_file = GLib.File.new_for_path (tmp_path);
            if (new_playlist_file.query_exists ()) {
                start_scanner (read_playlist (new_playlist_file, true), true);
            }
        }

        private void start_scanner (Gee.ArrayList<string> tracks, bool launch_player) {
            player.current_index = (uint) settings.get_uint64 ("current-media");

            if (tracks.size > 0) {
                if (scanner != null) {
                    stop_scanner ();
                }

                player.launch = launch_player;

                scanner = new CObjects.Scanner ();
                scanner.init ();
                scanner.discovered_new_item.connect (on_new_item);
                scanner.scan_tracks (tracks);
            }
        }

        private void stop_scanner () {
            scanner.discovered_new_item.disconnect (on_new_item);
            scanner.stop_scan ();
            scanner = null;
        }

        // private void update_current_playlist (uint[] tracks) {
        //     if (tracks.length > 0) {
        //         new GLib.Thread<void*> ("fill_queue", () => {
        //             var db_manager = DataBaseManager.to_write ();
        //             if (db_manager == null) {
        //                 return null;
        //             }
        //
        //             db_manager.update_playlist (queue_id, tracks, true);
        //             return null;
        //         });
        //     }
        // }



        private Gee.ArrayList<string> read_playlist (GLib.File playlist_file, bool launch_player) {
            Gee.ArrayList<string> tracks = new Gee.ArrayList<string> ();

            try {
                GLib.DataInputStream dis = new GLib.DataInputStream (playlist_file.read ());

                int slice_index = 0;
                string line;
                while ((line = dis.read_line ()) != null) {
                    if (line == "") {
                        continue;
                    }

                    if (launch_player && slice_index == 0 && player.current_index > 0 && line.hash () == player.current_index) {
                        slice_index = tracks.size;
                    }

                    tracks.add (line);
                }

                if (slice_index > 0) {
                    var tmp_arr = tracks.slice (0, slice_index);
                    tracks = tracks.slice (slice_index, tracks.size) as Gee.ArrayList<string>;
                    tracks.add_all (tmp_arr);
                }
            } catch (Error e) {
                warning ("Error: %s\n", e.message);
            }

            return tracks;
        }

        private void on_new_item (CObjects.Media? m) {
            if (m != null) {
                if (player.add_to_queue (m)) {
                    player.added_to_queue (m);
                    if (player.current_index == 0 || player.current_index == m.tid) {
                        player.current_index = m.tid;
                    }
                }
            }

            if (scanner.stopped_scan ()) {
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

        private void inhibit () {
            if (scrsaver_iface == null) {
                inhibit_cookie = null;

                return;
            }

            try {
                inhibit_cookie = scrsaver_iface.Inhibit (Constants.APP_NAME, "Playing music");
            } catch (Error e) {
                warning ("Could not inhibit screen: %s", e.message);
                return;
            }

            try {
                scrsaver_iface.SimulateUserActivity ();
            } catch (Error e) {
                warning ("Could not simulate user activity: %s", e.message);
            }
        }

        private void uninhibit () {
            if (inhibit_cookie != null) {
                if (scrsaver_iface != null) {
                    try {
                        scrsaver_iface.UnInhibit (inhibit_cookie);
                    } catch (Error e) {
                        warning ("Could not uninhibit screen: %s", e.message);
                    }
                }

                inhibit_cookie = null;
            }
        }
    }
}
