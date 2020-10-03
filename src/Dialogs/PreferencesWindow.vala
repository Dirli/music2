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
    public class Dialogs.PreferencesWindow : Gtk.Dialog {
        public PreferencesWindow (Music2.MainWindow main_win) {
            Object (
                border_width: 6,
                deletable: false,
                destroy_with_parent: true,
                height_request: Constants.DIALOG_MIN_HEIGHT,
                resizable: false,
                title: _("Preferences"),
                transient_for: main_win,
                width_request: Constants.DIALOG_MIN_WIDTH,
                window_position: Gtk.WindowPosition.CENTER_ON_PARENT
            );

            set_default_response (Gtk.ResponseType.CLOSE);

            var library_filechooser = new Gtk.FileChooserButton (_("Select Music Folder…"), Gtk.FileChooserAction.SELECT_FOLDER);
            library_filechooser.hexpand = true;
            var music_folder = main_win.settings.get_string ("music-folder");
            if (music_folder == "") {
                var default_filename = GLib.Environment.get_user_special_dir (GLib.UserDirectory.MUSIC);
                if (default_filename != null) {
                    music_folder = default_filename;
                }
            }

            library_filechooser.set_current_folder (music_folder);
            library_filechooser.file_set.connect (() => {
                string? filename = library_filechooser.get_filename ();
                if (filename != null) {
                    main_win.settings.set_string ("music-folder", filename);
                }
            });

            var organize_folders_switch = new Gtk.Switch ();
            organize_folders_switch.halign = Gtk.Align.START;
            main_win.settings.bind ("update-folder-hierarchy", organize_folders_switch, "active", GLib.SettingsBindFlags.DEFAULT);

            var import_all_files_switch = new Gtk.Switch ();
            import_all_files_switch.halign = Gtk.Align.START;
            main_win.settings.bind ("import-all-files", import_all_files_switch, "active", GLib.SettingsBindFlags.DEFAULT);

            var move_imported_music_switch = new Gtk.Switch ();
            move_imported_music_switch.halign = Gtk.Align.START;
            main_win.settings.bind ("move-imported-music", move_imported_music_switch, "active", GLib.SettingsBindFlags.DEFAULT);

            var hide_on_close_switch = new Gtk.Switch ();
            hide_on_close_switch.halign = Gtk.Align.START;
            main_win.settings.bind ("close-while-playing", hide_on_close_switch, "active", GLib.SettingsBindFlags.INVERT_BOOLEAN);

            var sleep_mode_switch = new Gtk.Switch ();
            sleep_mode_switch.halign = Gtk.Align.START;
            main_win.settings.bind ("block-sleep-mode", sleep_mode_switch, "active", GLib.SettingsBindFlags.DEFAULT);

            var layout = new Gtk.Grid ();
            layout.column_spacing = 12;
            layout.margin = 6;
            layout.row_spacing = 6;
            layout.attach (new Granite.HeaderLabel (_("Music Folder Location")), 0, 0);
            layout.attach (library_filechooser, 0, 1, 2, 1);
            layout.attach (new Granite.HeaderLabel (_("Library Management")), 0, 2);
            layout.attach (new SettingsLabel (_("Keep Music folder organized:")), 0, 3);
            layout.attach (organize_folders_switch, 1, 3);
            layout.attach (new SettingsLabel (_("import all files (not just music files):")), 0, 4);
            layout.attach (import_all_files_switch, 1, 4);
            layout.attach (new SettingsLabel (_("Move imported music (delete source):")), 0, 5);
            layout.attach (move_imported_music_switch, 1, 5);
            layout.attach (new Granite.HeaderLabel (_("Desktop Integration")), 0, 6);
            layout.attach (new SettingsLabel (_("Continue playback when closed:")), 0, 7);
            layout.attach (hide_on_close_switch, 1, 7);
            layout.attach (new SettingsLabel (_("Block sleep mode")), 0, 8);
            layout.attach (sleep_mode_switch, 1, 8);

            var content = get_content_area () as Gtk.Box;
            content.add (layout);

            add_button (_("Close"), Gtk.ResponseType.CLOSE);
            response.connect (() => {destroy ();});
        }

        private class SettingsLabel : Gtk.Label {
            public SettingsLabel (string text) {
                label = text;
                halign = Gtk.Align.END;
                hexpand = true;
                margin_start = 12;
            }
        }
    }
}
