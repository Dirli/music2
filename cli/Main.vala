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
    public class Cli.Daemon : GLib.Application {
        private const GLib.OptionEntry[] options = {
    		// --path=directory
            { "path", 0, 0, OptionArg.FILENAME, ref path, "Play music from this directory", "DIRECTORY" },
            // --run
            { "start", 0, 0, OptionArg.NONE, ref start, "Run current playlist", null },
            // --play
            { "play", 0, 0, OptionArg.NONE, ref play, "Toggle (play/pause) playing", null },
            // --prev
            { "prev", 0, 0, OptionArg.NONE, ref prev, "Play previous track", null },
            // --next
            { "next", 0, 0, OptionArg.NONE, ref next, "Play next track", null },
            // --stop
            { "stop", 0, 0, OptionArg.NONE, ref stop, "Stop playing", null },
            // --volume 50
            { "volume", 0, 0, OptionArg.INT, ref vol, "Set a new volume (-1 shows the current)", "0...100" },
            // --can_sleep=state
            { "can_sleep", 0, 0, OptionArg.STRING, ref sleep, "Set (show) the sleep mode status", "(true|false|state)" },
            //
            { "quit", 0, 0, OptionArg.NONE, ref close, "Quit the player", null },
    		// list terminator
    		{ null }
    	};

        private static string? path = null;
        private static string? sleep = null;
        private static int vol = -2;
        private static bool start = false;
        private static bool play = false;
        private static bool stop = false;
        private static bool next = false;
        private static bool prev = false;
        private static bool close = false;

        private PlayerIface? dbus_player = null;
        private static Daemon? instance = null;

        public static unowned Daemon get_instance (string[] args) {
            if (instance == null) {
                instance = new Daemon (args);
            }

            return instance;
        }

        private Daemon (string[] args) {
            application_id = "io.elementary.music2-cli";

            bool opt_error = false;

            try {
    			var opt_context = new GLib.OptionContext (null);
    			opt_context.set_help_enabled (true);
    			opt_context.add_main_entries (options, null);
    			opt_context.parse (ref args);
    		} catch (OptionError e) {
    			print ("error: %s\n", e.message);
    			print ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
                opt_error = true;

                GLib.Idle.add (() => {
                    Cli.Daemon.on_exit (0);
                    return false;
                });
            }

            if (!opt_error) {
                var settings = new GLib.Settings (Constants.APP_NAME);

                try {
                    dbus_player = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                           Constants.MPRIS_NAME,
                                                           Constants.MPRIS_PATH);

                    if (start) {
                        var _timer = 0;
                        GLib.Timeout.add_seconds (1, () => {
                            if (dbus_player.playback_status == "Stopped") {
                                if (_timer++ >= 5) {
                                    Cli.Daemon.on_exit (0);
                                    return false;
                                }

                                return true;
                            }

                            try {
                                dbus_player.play ();
                            } catch (Error e) {
                                warning (e.message);
                            }

                            Cli.Daemon.on_exit (0);
                            return false;
                        });
                    } else {
                        if (path != null) {
                            var to_save = "";
                            foreach (var s in Tools.FileUtils.get_audio_files (GLib.File.new_for_path (path))) {
                                to_save += @"$(s)\n";
                            }

                            if (to_save != "") {
                                settings.set_uint64 ("current-media", 0);
                                Tools.FileUtils.save_playlist (to_save, Tools.FileUtils.get_tmp_path ());
                            }
                        } else if (sleep != null) {
                            if (sleep == "true") {
                                settings.set_boolean ("block-sleep-mode", false);
                            } else if (sleep == "false") {
                                settings.set_boolean ("block-sleep-mode", true);
                            } else {
                                print (settings.get_boolean ("block-sleep-mode")
                                       ? _("Blocks the sleep mode") + "\n"
                                       : _("Sleep mode does not block") + "\n");
                            }
                        } else if (play) {
                            dbus_player.play_pause ();
                        } else if (stop) {
                            dbus_player.stop ();
                        } else if (next) {
                            dbus_player.next ();
                        } else if (prev) {
                            dbus_player.previous ();
                        } else if (vol >= -1) {
                            if (vol >= 0 && vol <= 100) {
                                dbus_player.volume = vol / 100.0;
                            } else {
                                print (@"Current volume $((int) (dbus_player.volume * 100))\n");
                            }
                        } else if (close) {
                            dbus_player.quit ();
                        }

                        GLib.Idle.add (() => {
                            Cli.Daemon.on_exit (0);
                            return false;
                        });
                    }
                } catch (Error e) {
                    warning (e.message);
                    Cli.Daemon.on_exit (0);
                }
            }
        }

        public override void activate () {
            hold ();
        }

        public static void on_exit (int signum) {
            GLib.Application.get_default ().release ();
        }
    }
}

public static int main (string[] args) {
    GLib.Process.signal (GLib.ProcessSignal.INT, Music2.Cli.Daemon.on_exit);
    GLib.Process.signal (GLib.ProcessSignal.TERM, Music2.Cli.Daemon.on_exit);
    return Music2.Cli.Daemon.get_instance (args).run ();
}
