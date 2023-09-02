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
    public class MainWindow : Gtk.ApplicationWindow {
        public GLib.Settings settings_ui;
        public GLib.Settings settings;

        private int queue_id = -5;

        private PlayerIface? dbus_player = null;
        private TrackListIface? dbus_tracklist = null;
        private DbusPropIface? dbus_prop = null;

        private Widgets.ViewStack view_stack;
        private Widgets.MusicStack music_stack;
        private Widgets.QueueStack queue_stack;
        private Widgets.PlaylistStack playlist_stack;

        private Widgets.SourceListView source_list_view;
        private Widgets.StatusBar status_bar;
        private Widgets.TopDisplay top_display;
        private Widgets.ActionStack action_stack;

        private Gtk.Button play_button;
        private Gtk.Button previous_button;
        private Gtk.Button next_button;

        private Gtk.MenuButton menu_button;

        private Views.ViewSelector view_selector;

        private Services.LibraryManager library_manager;
        private Services.PlaylistManager playlist_manager;
        private Services.LibraryScanner library_scanner = null;

        private bool has_music_folder {
            get {
                return settings_ui.get_string ("music-folder") != "";
            }
        }

        private uint _active_track = 0;
        public uint active_track {
            set {
                queue_stack.select_run_row (value);
                music_stack.select_run_row (value);
                playlist_stack.select_run_row (value);

                _active_track = value;

                update_title ();
            }
            get {
                return _active_track;
            }
        }

        private const GLib.ActionEntry[] ACTION_ENTRIES = {
            { Constants.ACTION_EDIT_SONG, action_edit_song, },
            { Constants.ACTION_IMPORT, action_import },
            { Constants.ACTION_PLAY, action_play },
            { Constants.ACTION_PLAY_NEXT, action_play_next },
            { Constants.ACTION_PLAY_PREVIOUS, action_play_previous },
            { Constants.ACTION_PREFERENCES, action_preferences },
            { Constants.ACTION_QUIT, action_quit },
            { Constants.ACTION_REMOVE_TRACK, action_remove_track, "i" },
            { Constants.ACTION_TO_PLAYLIST, action_to_playlist, "(ii)" },
            { Constants.ACTION_TO_QUEUE, action_to_queue, "i" },
            { Constants.ACTION_SEARCH, action_search },
            { Constants.ACTION_SHOW_BROWSER, action_show_browser, "(ii)" },
            { Constants.ACTION_SHOW_CURRENT, action_show_current },
            { Constants.ACTION_VIEW, action_view, "i" },
        };

        public MainWindow (Gtk.Application application) {
            Object (application: application,
                    height_request: 350,
                    width_request: 400,
                    icon_name: "multimedia-audio-player",
                    title: _("Music"));

            application.set_accels_for_action (Constants.ACTION_PREFIX + Constants.ACTION_QUIT, {"<Control>q"});
            application.set_accels_for_action (Constants.ACTION_PREFIX + Constants.ACTION_PLAY, {"<Control>space"});
            application.set_accels_for_action (Constants.ACTION_PREFIX + Constants.ACTION_PLAY_NEXT, {"<Control>n"});
            application.set_accels_for_action (Constants.ACTION_PREFIX + Constants.ACTION_PLAY_PREVIOUS, {"<Control>p"});
            application.set_accels_for_action (Constants.ACTION_PREFIX + Constants.ACTION_PREFERENCES, {"<Control>s"});
            application.set_accels_for_action (Constants.ACTION_PREFIX + Constants.ACTION_IMPORT, {"<Control>i"});
            application.set_accels_for_action (Constants.ACTION_PREFIX + Constants.ACTION_SEARCH, {"<Control>f"});
            application.set_accels_for_action (Constants.ACTION_PREFIX + Constants.ACTION_VIEW + "(0)", {"<Control>1"});
            application.set_accels_for_action (Constants.ACTION_PREFIX + Constants.ACTION_VIEW + "(1)", {"<Control>2"});

            var menu_popover = new Widgets.MenuPopover ();
            menu_button.popover = menu_popover;

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("io/elementary/music2/application.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var granite_settings = Granite.Settings.get_default ();
            var gtk_settings = Gtk.Settings.get_default ();

            gtk_settings.gtk_application_prefer_dark_theme =
                granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        
            granite_settings.notify["prefers-color-scheme"].connect (() => {
                gtk_settings.gtk_application_prefer_dark_theme =
                    granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            });
        }

        construct {
            var actions = new GLib.SimpleActionGroup ();
            actions.add_action_entries (ACTION_ENTRIES, this);
            insert_action_group ("win", actions);

            Tools.FileUtils.get_tmp_directory ();

            settings = new GLib.Settings (Constants.APP_NAME);
            settings_ui = new GLib.Settings (Constants.APP_NAME + ".ui");

            int window_x, window_y, window_width, window_height;
            settings_ui.get ("window-position", "(ii)", out window_x, out window_y);
            settings_ui.get ("window-size", "(ii)", out window_width, out window_height);

            set_default_size (window_width, window_height);

            if (window_x != -1 || window_y != -1) {
                move (window_x, window_y);
            }

            if (settings_ui.get_boolean ("window-maximized")) {
                maximize ();
            }

            library_manager = new Services.LibraryManager ();
            playlist_manager = new Services.PlaylistManager ();

            build_ui ();

            library_manager.library_loaded.connect (on_library_loaded);
            library_manager.added_category.connect (music_stack.add_column_item);

            source_list_view.add_item (queue_id, _("Queue"), Enums.Hint.QUEUE, new ThemedIcon ("playlist-queue"));
            source_list_view.update_badge (queue_id, 0);
            source_list_view.select_active_item (queue_id);

            try {
                dbus_player = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION, Constants.MPRIS_NAME, Constants.MPRIS_PATH);
                dbus_tracklist = GLib.Bus.get_proxy_sync (BusType.SESSION, Constants.MPRIS_NAME, Constants.MPRIS_PATH);
                dbus_prop = GLib.Bus.get_proxy_sync (BusType.SESSION, Constants.MPRIS_NAME, Constants.MPRIS_PATH);

                init_state ();

                dbus_tracklist.track_added.connect (on_track_added);
                dbus_tracklist.track_list_replaced.connect (on_track_list_replaced);
                dbus_tracklist.track_removed.connect (on_track_removed);
                dbus_prop.properties_changed.connect (on_properties_changed);
            } catch (Error e) {
                warning (e.message);
            }

            playlist_manager.add_view.connect (on_add_view);
            playlist_manager.cleared_playlist.connect (playlist_stack.clear_stack);
            playlist_manager.added_playlist.connect (source_list_view.add_item);

            playlist_manager.load_playlists ();
            changed_smart_playlists ();

            settings.bind ("auto-length", playlist_manager, "auto-length", GLib.SettingsBindFlags.GET);
            settings.changed["smart-playlists"].connect (changed_smart_playlists);
            settings_ui.changed["music-folder"].connect (changed_music_folder);

            if (has_music_folder) {
                source_list_view.add_item (-1, _("Music"), Enums.Hint.MUSIC, new ThemedIcon ("library-music"));
                new Thread<void> ("init_library", () => {
                    library_manager.init_library ();
                });
            } else if (settings_ui.get_boolean ("show-default-dialog")) {
                show_default_dir_dialog ();
            }
        }

        private void build_ui () {
            queue_stack = new Widgets.QueueStack ();
            queue_stack.selected_row.connect (on_selected_row);
            queue_stack.popup_media_menu.connect (on_popup_media_menu);

            music_stack = new Widgets.MusicStack ((Enums.ViewMode) settings_ui.get_enum ("view-mode"));
            music_stack.paned_position = settings_ui.get_int ("column-browser-height");
            music_stack.selected_row.connect (on_selected_row);
            music_stack.popup_media_menu.connect (on_popup_media_menu);
            music_stack.filter_categories.connect (on_filter_categories);
            music_stack.selected_album.connect (on_selected_album);
            music_stack.choose_album_cover.connect (run_file_chooser);
            music_stack.welcome_activate.connect (on_welcome_activate);

            playlist_stack = new Widgets.PlaylistStack ();
            playlist_stack.selected_row.connect (on_selected_row);
            playlist_stack.popup_media_menu.connect (on_popup_media_menu);

            source_list_view = new Widgets.SourceListView ();
            source_list_view.selection_changed.connect (on_selection_changed);
            source_list_view.menu_activated.connect (on_menu_activated);
            source_list_view.edited.connect (on_edited_playlist);

            action_stack = new Widgets.ActionStack ();
            action_stack.cancelled_scan.connect (() => {
                if (library_scanner != null) {
                    library_scanner.stop_scan ();
                }
            });
            action_stack.dnd_button_clicked.connect (on_dnd_button_clicked);

            status_bar = new Widgets.StatusBar ();
            status_bar.create_new_pl.connect (playlist_manager.create_playlist);
            status_bar.changed_volume.connect ((new_volume) => {
                dbus_player.volume = new_volume;
            });

            var left_grid = new Gtk.Grid ();
            left_grid.orientation = Gtk.Orientation.VERTICAL;
            left_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
            left_grid.add (source_list_view);
            left_grid.add (action_stack);
            left_grid.add (status_bar);

            Gtk.TargetEntry target = {"text/uri-list", 0, 0};
            Gtk.drag_dest_set (left_grid, Gtk.DestDefaults.ALL, {target}, Gdk.DragAction.COPY);
            left_grid.drag_data_received.connect (on_drag_data_received);

            view_stack = new Widgets.ViewStack ();
            view_stack.add_named (queue_stack, Constants.QUEUE);
            view_stack.add_named (music_stack, "music");
            view_stack.add_named (playlist_stack, "playlist");

            var main_hpaned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            main_hpaned.pack1 (left_grid, false, false);
            main_hpaned.pack2 (view_stack, true, false);

            settings_ui.bind ("sidebar-width", main_hpaned, "position", GLib.SettingsBindFlags.DEFAULT);
            main_hpaned.show_all ();

            add (main_hpaned);
            set_titlebar (build_header_bar ());
            show ();
        }

        private Gtk.HeaderBar build_header_bar () {
            previous_button = new Gtk.Button.from_icon_name ("media-skip-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            previous_button.action_name = Constants.ACTION_PREFIX + Constants.ACTION_PLAY_PREVIOUS;
            previous_button.tooltip_text = _("Previous");

            play_button = new Gtk.Button ();
            play_button.action_name = Constants.ACTION_PREFIX + Constants.ACTION_PLAY;

            next_button = new Gtk.Button.from_icon_name ("media-skip-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            next_button.action_name = Constants.ACTION_PREFIX + Constants.ACTION_PLAY_NEXT;
            next_button.tooltip_text = _("Next");

            view_selector = new Views.ViewSelector ();
            view_selector.mode_button.selected = settings_ui.get_enum ("view-mode");
            view_selector.mode_button.mode_changed.connect (on_mode_changed);
            view_selector.sensitive = false;

            menu_button = new Gtk.MenuButton ();
            menu_button.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.SMALL_TOOLBAR);
            menu_button.valign = Gtk.Align.CENTER;

            top_display = new Widgets.TopDisplay (settings.get_enum ("repeat-mode"), settings.get_boolean ("shuffle-mode"));
            top_display.seek_position.connect (on_seek_position);
            top_display.mode_option_changed.connect ((key, new_val) => {
                if (key != "shuffle-mode") {
                    settings.set_enum (key, new_val);
                } else {
                    settings.set_boolean (key, new_val == 0 ? false : true);
                }
            });
            top_display.popup_media_menu.connect ((x_point, y_point) => {
                if (active_track > 0) {
                    uint[] tids = {active_track};

                    Gdk.Rectangle rect = Gdk.Rectangle () {
                        x = (int) x_point,
                        y = (int) y_point,
                        height = 1,
                        width = 1
                    };

                    on_popup_media_menu (Enums.Hint.QUEUE, tids, rect, top_display);
                }
            });

            var headerbar = new Gtk.HeaderBar ();
            headerbar.show_close_button = true;
            headerbar.pack_start (previous_button);
            headerbar.pack_start (play_button);
            headerbar.pack_start (next_button);
            headerbar.pack_start (view_selector);
            headerbar.pack_end (menu_button);
            headerbar.set_title (_("Music"));
            headerbar.set_custom_title (top_display);
            headerbar.show_all ();

            return headerbar;
        }

        private void init_state () {
            status_bar.set_new_volume (dbus_player.volume);

            previous_button.sensitive = dbus_player.can_go_previous;
            next_button.sensitive = dbus_player.can_go_next;

            var metadata = dbus_player.metadata;
            if (metadata != null && "mpris:trackid" in metadata) {
                active_track = (uint) metadata["mpris:trackid"].get_int64 ();

                string play_state = dbus_player.playback_status;
                int64 play_position = 0;
                try {
                    int64 p = dbus_player.get_track_position ();
                    play_position = Tools.TimeUtils.micro_to_nano (p);
                } catch (Error e) {
                    warning (e.message);
                }

                int64 duration = Tools.TimeUtils.micro_to_nano (dbus_player.duration);
                top_display.duration = duration;

                changed_state (play_state, play_position);

                var tracks_id = dbus_tracklist.tracks;
                if (tracks_id.length > 0) {
                    try {
                        var tracks_meta = dbus_tracklist.get_tracks_metadata (tracks_id);
                        foreach (unowned GLib.HashTable<string, GLib.Variant> meta in tracks_meta) {
                            on_track_added (meta);
                        }
                    } catch (Error e) {
                        warning (e.message);
                    }
                }
            } else {
                play_button.sensitive = false;
                play_button.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            }
        }

        // actions
        private void action_play () {
            try {
                dbus_player.play_pause ();
            } catch (Error e) {
                warning (e.message);
            }
        }

        private void action_play_next () {
            try {
                dbus_player.next ();
            } catch (Error e) {
                warning (e.message);
            }
        }

        private void action_play_previous () {
            try {
                dbus_player.previous ();
            } catch (Error e) {
                warning (e.message);
            }
        }

        private void action_quit () {
            try {
                dbus_player.stop ();
                dbus_player.quit ();
            } catch (Error e) {
                warning (e.message);
            }

            destroy ();
        }

        private void action_search () {
            //  do something
        }

        private void action_preferences () {
            var preferences = new Dialogs.PreferencesWindow (this);

            preferences.run ();
        }

        private void action_import () {
            if (library_scanner != null) {
                return;
            }

            var f = run_file_chooser (_("Import Music"), Gtk.FileChooserAction.SELECT_FOLDER, null);
            if (f != null) {
                on_import_folder (f);
            }
        }

        private void action_view (GLib.SimpleAction action, GLib.Variant? pars) {
            int tid;
            pars.get ("i", out tid);

            view_selector.mode_button.selected = tid;
        }

        private void action_show_current () {
            var visible_widget = view_stack.get_visible_child ();
            if (visible_widget is Widgets.MusicStack) {
                ((Widgets.MusicStack) visible_widget).scroll_to_current (active_track);
            } else if (visible_widget is Interfaces.ListStack) {
                var list_stack = visible_widget as Interfaces.ListStack;
                if (list_stack != null) {
                    list_stack.scroll_to_current (active_track);
                }
            }
        }

        private void action_show_browser (GLib.SimpleAction action, GLib.Variant? pars) {
            int hint;
            int tid;
            pars.@get ("(ii)", out hint, out tid);

            CObjects.Media? media = null;
            if (Enums.Hint.QUEUE == hint) {
                try {
                    uint[] tids = {(uint) tid};
                    var tracks_meta = dbus_tracklist.get_tracks_metadata (tids);
                    if (tracks_meta.length > 0) {
                        media = Tools.GuiUtils.metadata_to_media (tracks_meta[0]);
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            } else if (Enums.Hint.MUSIC == hint) {
                media = library_manager.get_media ((uint) tid);
            }

            if (media != null) {
                try {
                    var m_file = GLib.File.new_for_uri (media.uri);
                    Gtk.show_uri_on_window (this, m_file.get_parent ().get_uri (), Gdk.CURRENT_TIME);
                } catch (Error err) {
                    warning ("Could not browse media %s: %s\n", media.uri, err.message);
                }
            }
        }

        private void action_edit_song () {
            // do something
        }

        private void action_to_queue (GLib.SimpleAction action, GLib.Variant? pars) {
            int tid;
            pars.@get ("i", out tid);
            var m = library_manager.get_media (tid);
            if (m != null) {
                try {
                    dbus_tracklist.add_track (m.uri, 0, false);
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }

        private void action_to_playlist (GLib.SimpleAction action, GLib.Variant? pars) {
            int pid;
            int tid;
            pars.@get ("(ii)", out pid, out tid);

            if (playlist_stack.pid == pid) {
                if (on_add_view ((uint) tid)) {
                    playlist_stack.modified = true;
                }
            } else {
                playlist_manager.add_to_playlist (pid, (uint) tid);
            }
        }

        private void action_remove_track (GLib.SimpleAction action, GLib.Variant? pars) {
            int tid;
            pars.get ("i", out tid);
            var view_name = view_stack.get_visible_child_name ();
            if (view_name != null) {
                switch (view_name) {
                    case Constants.QUEUE:
                        try {
                            dbus_tracklist.remove_track ((uint) tid);
                        } catch (Error e) {
                            warning (e.message);
                        }
                        break;
                    case "playlist":
                        if (playlist_stack.remove_iter ((uint) tid) > 0) {
                            playlist_stack.modified = true;
                        }
                        break;
                    case "music":
                        // do something
                        break;
                }
            }
        }

        // dbus signal handler
        private void on_properties_changed (string iface, GLib.HashTable<string, GLib.Variant> changed_prop, string[] invalid) {
            if (iface == "org.mpris.MediaPlayer2.Player") {
                changed_prop.foreach ((k, v) => {
                    if (k == "Metadata") {
                        GLib.VariantIter iter = null;
                        v.get ("a{sv}", out iter);

                        if (iter != null) {
                            GLib.Variant? val = null;
                            string? key = null;
                            while (iter.next ("{sv}", out key, out val)) {
                                if (val == null) {continue;}
                                if (key == "mpris:trackid") {
                                    active_track = (uint) val.get_int64 ();
                                    break;
                                }

                                val = null;
                            }
                        }
                    } else if (k == "Volume") {
                        status_bar.set_new_volume (v.get_double ());
                    } else if (k == "Duration") {
                        top_display.duration = Tools.TimeUtils.micro_to_nano (v.get_int64 ());
                    } else if (k == "PlaybackStatus") {
                        int64 play_position = 0;
                        try {
                            int64 p = dbus_player.get_track_position ();
                            play_position = Tools.TimeUtils.micro_to_nano (p);
                        } catch (Error e) {
                            warning (e.message);
                        }
                        changed_state (v.get_string (), play_position);
                    } else if (k == "CanGoNext") {
                        next_button.sensitive = v.get_boolean ();
                    } else if (k == "CanGoPrevious") {
                        previous_button.sensitive = v.get_boolean ();
                    }
                });
            }
        }

        private void on_track_added (GLib.HashTable<string, GLib.Variant> metadata, uint after_tid = 0) {
            var m = Tools.GuiUtils.metadata_to_media (metadata);
            if (m != null) {
                add_to_queue (m);
            }
        }

        private void on_track_list_replaced (uint[] tracks, uint cur_track) {
            source_list_view.update_badge (queue_id, 0);
            queue_stack.clear_stack ();

            top_display.stop_progress ();
            top_display.set_visible_child_name ("empty");

            fill_queue (tracks);
        }

        private void on_track_removed (uint tid) {
            var inc_size = queue_stack.remove_iter (tid);
            source_list_view.update_badge (queue_id, inc_size);
        }

        // signals
        private void on_seek_position (int64 new_position) {
            try {
                dbus_player.seek (new_position);
            } catch (Error e) {
                warning (e.message);
            }
        }

        private void on_popup_media_menu (Enums.Hint hint, uint[] tids, Gdk.Rectangle rect, Gtk.Widget w) {
            var main_menu = new GLib.Menu ();

            if (active_track > 0 && hint == Enums.Hint.QUEUE) {
                var scroll_item = new GLib.MenuItem (_("Scroll to Current Song"), Constants.ACTION_PREFIX + Constants.ACTION_SHOW_CURRENT);
                main_menu.append_item (scroll_item);
            }

            var browser_item = new GLib.MenuItem (_("Show in File Browser"), "win.action_show_browser((%d,%d))".printf (hint, (int) tids[0]));
            main_menu.append_item (browser_item);
            var edit_item = new GLib.MenuItem (_("Edit Song Info…"), Constants.ACTION_PREFIX + Constants.ACTION_EDIT_SONG);
            main_menu.append_item (edit_item);

            if (hint == Enums.Hint.MUSIC || hint == Enums.Hint.PLAYLIST || hint == Enums.Hint.SMART_PLAYLIST) {
                if (!queue_stack.exist_iter (tids[0])) {
                    var queue_item = new GLib.MenuItem (_("Add to Queue"), "win.action_to_queue(%d)".printf ((int) tids[0]));
                    main_menu.append_item (queue_item);
                }
            }

            string remove_label = hint == Enums.Hint.QUEUE ? _("Remove from Queue") :
                                  hint == Enums.Hint.MUSIC ? _("Remove from Library") :
                                  hint == Enums.Hint.PLAYLIST ? _("Remove from Playlist") : "";

            var remove_item = new GLib.MenuItem (remove_label, "win.action_remove_track(%d)".printf ((int) tids[0]));
            main_menu.append_item (remove_item);

            if (hint == Enums.Hint.MUSIC || hint == Enums.Hint.QUEUE) {
                var available_pl = playlist_manager.get_available_playlists (tids[0]);
                if (available_pl.size > 0) {
                    var playlist_menu = new GLib.Menu ();

                    var playlist_item = new GLib.MenuItem.submenu (_("Add to playlist..."), playlist_menu);
                    main_menu.append_item (playlist_item);

                    available_pl.foreach ((playlist) => {
                        var pl_menu_item = new GLib.MenuItem (playlist.value, "win.action_to_playlist((%d,%d))".printf (playlist.key, (int) tids[0]));
                        playlist_menu.append_item (pl_menu_item);

                        return true;
                    });
                }
            }

            var media_menu = new Gtk.Popover.from_model (w, main_menu);
            media_menu.set_pointing_to (rect);

            media_menu.show_all ();
        }

        private void on_import_folder (GLib.File folder) {
            GLib.Timeout.add (400, () => {
                if (folder.query_exists ()) {
                    var import_dialog = new Dialogs.ImportFolder (this, folder.get_path ());
                    import_dialog.response.connect ((response_id) => {
                        if (response_id == Gtk.ResponseType.APPLY) {
                            new Thread<void> ("import_folder", () => {
                                library_manager.import_folder (folder.get_uri (), settings_ui.get_string ("music-folder"));
                            });
                        }

                        import_dialog.destroy ();
                    });

                    import_dialog.show_all ();
                    import_dialog.run ();
                }

                return false;
            });
        }

        private void on_mode_changed () {
            var view_mode = (Enums.ViewMode) view_selector.mode_button.selected;
            music_stack.show_view (view_mode);
            settings_ui.set_enum ("view-mode", view_mode);
            source_list_view.select_active_item (-1);
        }

        private void on_selection_changed (int pid, Enums.Hint hint) {
            if (view_stack.visible_child_name == "playlist" && playlist_stack.modified) {
                var old_pid = playlist_stack.pid;
                var tracks = playlist_stack.get_playlist ();
                new Thread<void> ("update_playlist", () => {
                    playlist_manager.update_playlist (old_pid, tracks);
                });

                playlist_stack.modified = false;
            }

            switch (hint) {
                case Enums.Hint.QUEUE:
                    view_stack.set_visible_child_name (Constants.QUEUE);
                    break;
                case Enums.Hint.SMART_PLAYLIST:
                case Enums.Hint.PLAYLIST:
                    view_stack.set_visible_child_name ("playlist");
                    select_playlist_item (pid, hint);
                    break;
                case Enums.Hint.MUSIC:
                    view_stack.set_visible_child_name ("music");
                    break;
                default:
                    break;
            }
        }

        private void on_filter_categories (Enums.Category c, int id) {
            for (var i = (int) c + 1; i < Enums.Category.N_CATEGORIES; i++) {
                if (id == -1) {
                    music_stack.filter_category ((Enums.Category) i, new Gee.ArrayList<int> ());
                } else {
                    var id_arr = library_manager.get_filtered_category ((Enums.Category) i, c, id);
                    if (id_arr != null) {
                        music_stack.filter_category ((Enums.Category) i, id_arr);
                    }
                }
            }
        }

        private void on_selected_album (int album_id) {
            var a_tracks = library_manager.get_album_tracks (album_id);
            if (a_tracks.size > 0) {
                music_stack.add_album_tracks (a_tracks);
            }
        }

        private void on_selected_row (uint row_id, Enums.Hint active_hint) {
            if (active_hint == Enums.Hint.QUEUE) {
                run_selected_row (row_id);
                return;
            }

            if (library_scanner != null) {
                return;
            }

            settings.set_uint64 ("current-media", row_id);

            if (active_hint == Enums.Hint.MUSIC) {
                var tids = music_stack.get_filter_tracks ();
                if (playlist_from_library (tids)) {
                    return;
                }
            } else if (active_hint >= Enums.Hint.PLAYLIST) {
                var tids = playlist_stack.get_playlist ();
                if (playlist_from_library (tids)) {
                    return;
                }
            }

            settings.set_uint64 ("current-media", 0);
        }

        private void on_menu_activated (Views.SourceListItem item, Enums.ActionType action_type) {
            switch (action_type) {
                case Enums.ActionType.SCAN:
                    if (item.hint == Enums.Hint.MUSIC) {
                        start_scanning_library ();
                    }
                    break;
                case Enums.ActionType.CLEAR:
                    if (item.hint == Enums.Hint.QUEUE) {
                        // do something
                    } else if (item.hint == Enums.Hint.PLAYLIST) {
                        var pid = item.pid;
                        playlist_manager.clear_playlist (pid, pid == playlist_stack.pid);
                    }

                    break;
                case Enums.ActionType.SAVE:
                    if (item.hint == Enums.Hint.QUEUE) {
                        var pid = playlist_manager.create_playlist (_("Queue"));
                        if (pid > 0) {
                            try {
                                var tracks = dbus_tracklist.get_tracklist ();
                                foreach (var tid in tracks) {
                                    if (library_manager.in_library (tid)) {
                                        playlist_manager.add_to_playlist (pid, tid);
                                    }
                                }
                            } catch (Error e) {
                                warning (e.message);
                            }
                        }
                    }
                    break;
                case Enums.ActionType.REMOVE:
                    if (item.hint == Enums.Hint.PLAYLIST) {
                        var pid = item.pid;
                        if (playlist_manager.remove_playlist (pid, pid == playlist_stack.pid)) {
                            source_list_view.remove_item (pid);
                        }
                    }
                    break;
                case Enums.ActionType.EXPORT:
                    export_playlist (item);
                    break;
                case Enums.ActionType.EDIT:
                    if (item.hint == Enums.Hint.SMART_PLAYLIST) {
                        edit_smart_playlists ();
                    }
                    break;
                default:
                    break;
            }
        }

        private void on_welcome_activate (int index) {
            if (index == 2) {
                start_scanning_library ();
            }
        }

        private bool on_add_view (uint tid) {
            var m = library_manager.get_media (tid);
            if (m != null) {
                playlist_stack.add_iter (m);
                if (active_track >= 0 && m.tid == active_track) {
                    playlist_stack.select_run_row (active_track);
                }

                return true;
            }

            return false;
        }

        private void on_prepare_scan () {
            action_stack.init_progress ();
            music_stack.show_alert ();
        }

        private void on_finished_scan (int64 total_scans, int64 scan_time) {
            library_scanner = null;

            action_stack.hide_widget ("progress");

            new Thread<void> ("init_library", () => {
                library_manager.init_library ();
            });
        }

        private void on_library_loaded () {
            music_stack.add_tracks (library_manager.get_track_list ());
            music_stack.add_album_grid (library_manager.get_albums (),
                                        library_manager.get_artists_per_albums ());

            view_selector.sensitive = true;
            music_stack.init_selections (active_track);
            status_bar.sensitive_btns (true);
        }

        private void on_edited_playlist (int pid, string playlist_name) {
            if (queue_id != pid) {
                var modified_name = playlist_manager.edit_playlist (pid, playlist_name);
                if (modified_name != "") {
                    source_list_view.rename_playlist (pid, modified_name);
                }
            }
        }

        private void on_dnd_button_clicked (Enums.ActionType action_type, string uri) {
            switch (action_type) {
                case Enums.ActionType.PLAY:
                    source_list_view.select_active_item (queue_id);

                    var to_save = "";
                    foreach (var s in Tools.FileUtils.get_audio_files (uri)) {
                        to_save += @"$(s)\n";
                    }

                    settings.set_uint64 ("current-media", 0);
                    Tools.FileUtils.save_playlist (to_save, Tools.FileUtils.get_tmp_path ());

                    break;
                case Enums.ActionType.IMPORT:
                    if (library_scanner == null) {
                        on_import_folder (GLib.File.new_for_uri (uri));
                    }
                    break;
                default:
                    break;
            }
        }

        private void on_drag_data_received (Gdk.DragContext ctx, int x, int y, Gtk.SelectionData sel, uint info, uint time) {
            var uris = sel.get_uris ();
            if (uris.length > 0) {
                var path_file = GLib.File.new_for_uri (uris[0]);
                var file_type = path_file.query_file_type (GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

                if (file_type == GLib.FileType.DIRECTORY) {
                    action_stack.init_dnd (uris[0]);
                } else if (file_type == GLib.FileType.REGULAR) {
                    var file_name = path_file.get_basename ();
                    if (file_name != null) {
                        if (file_name.has_suffix (".m3u")) {
                            var to_save = Tools.FileUtils.get_playlist_m3u (uris[0]);

                            settings.set_uint64 ("current-media", 0);
                            Tools.FileUtils.save_playlist (to_save, Tools.FileUtils.get_tmp_path ());
                        }
                    }
                }

                Gtk.drag_finish (ctx, true, false, time);
            }
        }

        // changes
        private void changed_music_folder () {
            if (has_music_folder) {
                music_stack.show_welcome ();
                view_stack.set_visible_child_name ("music");
            } else {
                // do something
            }
        }

        private void changed_smart_playlists () {
            int8 playlists_status = (int8) settings.get_int ("smart-playlists");

            if ((playlists_status & 1) == 0) {
                source_list_view.remove_item (Constants.NEVER_PLAYED_ID);
                source_list_view.remove_item (Constants.FAVORITE_SONGS_ID);
                source_list_view.remove_item (Constants.RECENTLY_PLAYED_ID);
            } else {
                if ((playlists_status & 2) > 0) {
                    source_list_view.add_item (Constants.NEVER_PLAYED_ID, Constants.NEVER_PLAYED, Enums.Hint.SMART_PLAYLIST, new ThemedIcon ("playlist-automatic"));
                } else {
                    source_list_view.remove_item (Constants.NEVER_PLAYED_ID);
                }
                if ((playlists_status & 4) > 0) {
                    source_list_view.add_item (Constants.FAVORITE_SONGS_ID, Constants.FAVORITE_SONGS, Enums.Hint.SMART_PLAYLIST, new ThemedIcon ("playlist-automatic"));
                } else {
                    source_list_view.remove_item (Constants.FAVORITE_SONGS_ID);
                }
                if ((playlists_status & 8) > 0) {
                    source_list_view.add_item (Constants.RECENTLY_PLAYED_ID, Constants.RECENTLY_PLAYED, Enums.Hint.SMART_PLAYLIST, new ThemedIcon ("playlist-automatic"));
                } else {
                    source_list_view.remove_item (Constants.RECENTLY_PLAYED_ID);
                }
            }
        }

        private void changed_state (string play_state, int64 p) {
            if (p > 0) {
                top_display.set_progress (p);
            }

            switch (play_state) {
                case "Playing":
                    play_button.sensitive = true;
                    top_display.start_progress ();
                    break;
                case "Paused":
                    play_button.sensitive = true;
                    top_display.pause_progress ();
                    break;
                case "Stopped":
                default:
                    if (settings.get_enum ("repeat-mode") != Enums.RepeatMode.MEDIA) {
                        top_display.stop_progress ();
                        var tid = _active_track;
                        if (tid > 0) {
                            queue_stack.remove_run_icon (tid);
                            music_stack.remove_run_icon (tid);
                            playlist_stack.remove_run_icon (tid);
                        }
                    }
                    break;
            }

            play_button.tooltip_text = play_state == "Playing" ? _("Pause") : _("Play");
            play_button.image = new Gtk.Image.from_icon_name (play_state == "Playing" ?
                                                              "media-playback-pause-symbolic" :
                                                              "media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        }

        public void open_files (GLib.File[] files) {
            string to_save = Tools.FileUtils.files_to_str (files);

            settings.set_uint64 ("current-media", 0);
            Tools.FileUtils.save_playlist (to_save, Tools.FileUtils.get_tmp_path ());
        }

        private GLib.File run_file_chooser (string title, Gtk.FileChooserAction a, Gtk.FileFilter? filter) {
            var file_chooser = new Gtk.FileChooserNative (
                title,
                this,
                a,
                _("_Open"),
                _("_Cancel")
            );

            file_chooser.set_select_multiple (false);
            // file_chooser.set_local_only (true);

            if (filter != null) {
                file_chooser.add_filter (filter);
            }

            GLib.File f = null;
            if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
                f = file_chooser.get_file ();
            }

            file_chooser.destroy ();
            return f;
        }

        private void fill_queue (owned uint[] tids) {
            new Thread<void> ("fill_queue", () => {
                try {
                    var tracks_meta = dbus_tracklist.get_tracks_metadata (tids);
                    foreach (unowned GLib.HashTable<string, GLib.Variant> meta in tracks_meta) {
                        on_track_added (meta);
                    }
                } catch (GLib.Error e) {
                    warning (e.message);
                }
            });
        }

        private void select_playlist_item (int pid, Enums.Hint playlist_hint) {
            if (playlist_stack.pid != pid) {
                playlist_stack.init_store (pid, playlist_hint);
            } else if (playlist_hint == Enums.Hint.SMART_PLAYLIST) {
                playlist_stack.clear_stack ();
            } else {
                return;
            }

            playlist_manager.select_playlist (pid, playlist_hint);
        }

        private void add_to_queue (CObjects.Media m) {
            var queue_size = queue_stack.add_iter (m);
            source_list_view.update_badge (queue_id, queue_size);

            if (active_track >= 0 && m.tid == active_track) {
                queue_stack.select_run_row (active_track);
            }
        }

        private void start_scanning_library () {
            if (library_scanner != null) {
                return;
            }

            if (library_manager.library_not_empty) {
                library_manager.clear_library ();
                music_stack.clear_stack ();

                view_selector.sensitive = false;
                status_bar.sensitive_btns (false);
            }

            if (has_music_folder) {
                new Thread<void> ("scan_directory", run_scanner);
            } else {
                source_list_view.select_active_item (1);
                source_list_view.remove_item (-1);
            }
        }

        private void run_scanner () {
            library_scanner = new Services.LibraryScanner ();

            library_scanner.progress_scan.connect (action_stack.update_progress);
            library_scanner.prepare_scan.connect (on_prepare_scan);
            library_scanner.finished_scan.connect (on_finished_scan);

            var music_dir = GLib.File.new_for_path (settings_ui.get_string ("music-folder"));
            library_scanner.start_scan (music_dir.get_uri ());
        }

        private void show_default_dir_dialog () {
            var default_dir_dialog = new Dialogs.DefaultMusicDir (settings_ui) {
                transient_for = this
            };

            default_dir_dialog.show_all ();
            default_dir_dialog.run ();
        }

        private void edit_smart_playlists () {
            var smart_preferences = new Dialogs.SmartPlaylistEditor (this);

            smart_preferences.show_all ();
            smart_preferences.run ();
        }

        private bool playlist_from_library (Gee.ArrayQueue<uint> tids) {
            var to_save = "";
            tids.foreach ((tid) => {
                var m = library_manager.get_media (tid);
                if (m != null) {
                    to_save += @"$(m.uri)\n";
                }

                return true;
            });

            if (to_save != "") {
                return Tools.FileUtils.save_playlist (to_save, Tools.FileUtils.get_tmp_path ());
            }

            return false;
        }

        private void export_playlist (Views.SourceListItem item) {
            var hint = item.hint;
            var pid = item.pid;
            CObjects.Media[] tracks = {};
            if (hint == Enums.Hint.QUEUE) {
                try {
                    var tids = dbus_tracklist.get_tracklist ();
                    var tracks_meta = dbus_tracklist.get_tracks_metadata (tids);
                    foreach (unowned GLib.HashTable<string, GLib.Variant> meta in tracks_meta) {
                        var m = Tools.GuiUtils.metadata_to_media (meta);
                        if (m != null) {
                            tracks += m;
                        }
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            } else if (hint == Enums.Hint.PLAYLIST || hint == Enums.Hint.SMART_PLAYLIST) {
                var tids = playlist_stack.pid == pid
                           ? playlist_stack.get_playlist ()
                           : playlist_manager.get_playlist (pid);
                if (tids != null) {
                    tids.foreach ((tid) => {
                        var m = library_manager.get_media (tid);
                        if (m != null) {
                            tracks += m;
                        }

                        return true;
                    });
                }
            }

            if (tracks.length > 0) {
                var path = Tools.GuiUtils.get_playlist_path (item.name, settings_ui.get_string ("music-folder"));
                new Thread<void> ("export_playlist", () => {
                    Tools.FileUtils.save_playlist_m3u (path, tracks);
                });
            }
        }

        private void run_selected_row (uint row_id) {
            if (row_id > 0) {
                try {
                    dbus_tracklist.go_to (row_id);
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }

        private void update_title () {
            var metadata = dbus_player.metadata;
            CObjects.Media? m = Tools.GuiUtils.metadata_to_media (metadata);

            if (m != null) {
                top_display.set_title_markup (m);
            }
        }

        public override bool delete_event (Gdk.EventAny event) {
            if (playlist_stack.modified) {
                playlist_manager.update_playlist (playlist_stack.pid, playlist_stack.get_playlist ());
            }
            settings_ui.set_int ("column-browser-height", music_stack.paned_position);
            settings_ui.set_boolean ("window-maximized", is_maximized);

            if (!is_maximized) {
                int width, height, root_x, root_y;
                get_position (out root_x, out root_y);
                get_size (out width, out height);

                settings_ui.set ("window-position", "(ii)", root_x, root_y);
                settings_ui.set ("window-size", "(ii)", width, height);
            }

            try {
                dbus_player.quit ();
            } catch (Error e) {
                warning (e.message);
            }

            return false;
        }
    }
}
