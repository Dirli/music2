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
    public class Widgets.TopDisplay : Gtk.Stack {
        public signal void mode_option_changed (string mode_name, int option_val);
        public signal void seek_position (int64 offset);
        public signal void popup_media_menu ();

        private uint progress_timer = 0;
        private uint seek_timer = 0;
        private int64 progress = 0;

        public int64 duration {
            set {
                seek_bar.playback_duration = value / Gst.SECOND;
            }
        }

        private TitleLabel track_label;
        private Granite.SeekBar seek_bar;

        ~TopDisplay () {
            pause_progress ();
        }

        public TopDisplay (int repeat_mode, int shuffle_mode) {
            seek_bar = new Granite.SeekBar (0.0);

            var shuffle_chooser = new Views.OptionChooser ();
            shuffle_chooser.append_item ("media-playlist-consecutive-symbolic", _("Enable Shuffle"));
            shuffle_chooser.append_item ("media-playlist-shuffle-symbolic", _("Disable Shuffle"));
            shuffle_chooser.set_option (shuffle_mode);

            var repeat_chooser = new Views.OptionChooser ();
            repeat_chooser.append_item ("media-playlist-no-repeat-symbolic", _("Enable Repeat"));
            repeat_chooser.append_item ("media-playlist-repeat-song-symbolic", _("Repeat Song"));
            repeat_chooser.append_item ("media-playlist-repeat-symbolic", _("Disable Repeat"));
            repeat_chooser.set_option (repeat_mode);

            track_label = new TitleLabel ("");

            var track_eventbox = new Gtk.EventBox ();
            track_eventbox.add (track_label);
            track_eventbox.button_press_event.connect ((e) => {
                if (e.button == Gdk.BUTTON_SECONDARY) {
                    popup_media_menu ();
                }
                return false;
            });

            var time_grid = new Gtk.Grid ();
            time_grid.column_spacing = 12;
            time_grid.attach (shuffle_chooser, 0, 0, 1, 1);
            time_grid.attach (track_eventbox,  1, 0, 1, 1);
            time_grid.attach (repeat_chooser,  2, 0, 1, 1);
            time_grid.attach (seek_bar,        0, 1, 3, 1);

            var empty_grid = new Gtk.Grid ();
            transition_type = Gtk.StackTransitionType.CROSSFADE;

            add_named (time_grid, "time");
            add_named (empty_grid, "empty");

            shuffle_chooser.option_changed.connect ((option_val) => {
                mode_option_changed ("shuffle-mode", option_val);
            });
            repeat_chooser.option_changed.connect ((option_val) => {
                mode_option_changed ("repeat-mode", option_val);
            });

            get_style_context ().add_class (Gtk.STYLE_CLASS_TITLE);
            show_all ();
            visible_child = empty_grid;

            seek_bar.scale.change_value.connect (on_change_value);
        }

        public void start_progress () {
            pause_progress ();
            change_progress ();
            progress_timer = GLib.Timeout.add (Constants.INTERVAL, change_progress);
        }

        public void pause_progress () {
            if (progress_timer != 0) {
                Source.remove (progress_timer);
                progress_timer = 0;
            }
        }

        public void stop_progress () {
            pause_progress ();
            progress = 0;
            track_label.set_markup ("");
        }

        private bool change_progress () {
            seek_bar.playback_progress = 1.0 / seek_bar.playback_duration * (progress / Constants.MILI_INV);
            progress += Constants.INTERVAL;
            return true;
        }

        public void set_progress (int64 p) {
            progress = p / 1000000;
            change_progress ();
        }

        public virtual bool on_change_value (Gtk.ScrollType scroll, double val) {
            int64 new_position = Tools.TimeUtils.sec_to_micro ((int64) (val * seek_bar.playback_duration));
            int64 old_position = progress * 1000;
            progress = new_position / 1000;

            if (seek_timer > 0) {
                Source.remove (seek_timer);
            }

            seek_timer = Timeout.add (300, () => {
                if (!seek_bar.is_grabbing) {
                    seek_position (new_position - old_position);
                }

                seek_timer = 0;
                return false;
            });

            return false;
        }

        public void set_title_markup (CObjects.Media m) {
            bool is_valid_artist = !Tools.String.is_empty (m.artist);
            bool is_valid_album = !Tools.String.is_empty (m.album);

            string message = "";

            if (!is_valid_artist && is_valid_album) {
                message = _("$NAME on $ALBUM")
                .replace ("$ALBUM", "<b>" + GLib.Markup.escape_text (m.album) + "</b>")
                .replace ("$NAME", "<b>" + GLib.Markup.escape_text (m.get_display_title ()) + "</b>");
            } else if (is_valid_artist && !is_valid_album) {
                message = _("$NAME by $ARTIST")
                .replace ("$ARTIST", "<b>" + GLib.Markup.escape_text (m.artist) + "</b>")
                .replace ("$NAME", "<b>" + GLib.Markup.escape_text (m.get_display_title ()) + "</b>");
            } else if (!is_valid_artist && !is_valid_album) {
                message = "<b>" + GLib.Markup.escape_text (m.get_display_title ()) + "</b>";
            } else {
                message = _("$NAME by $ARTIST on $ALBUM")
                .replace ("$ARTIST", "<b>" + GLib.Markup.escape_text (m.artist) + "</b>")
                .replace ("$NAME", "<b>" + GLib.Markup.escape_text (m.get_display_title ()) + "</b>")
                .replace ("$ALBUM", "<b>" + GLib.Markup.escape_text (m.album) + "</b>");
            }

            track_label.set_markup (message);
        }

        public override void get_preferred_width (out int minimum_width, out int natural_width) {
            base.get_preferred_width (out minimum_width, out natural_width);
            minimum_width = 200;

            if (natural_width < 600) {
                natural_width = 600;
            }
        }

        private class TitleLabel : Gtk.Label {
            public TitleLabel (string label) {
                Object (label: label);
                hexpand = true;
                justify = Gtk.Justification.CENTER;
                ellipsize = Pango.EllipsizeMode.END;
            }
        }
    }
}
