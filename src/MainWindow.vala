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
        private GLib.Settings settings_ui;
        public GLib.Settings settings;

        private bool queue_reset = false;
        private bool scans_library = false;

        private PlayerIface? dbus_player = null;
        private TrackListIface? dbus_tracklist = null;
        private DbusPropIface? dbus_prop = null;

        private Widgets.ViewStack view_stack;
        private Widgets.MusicStack music_stack;
        private Widgets.QueueStack queue_stack;

        private Widgets.SourceListView source_list_view;
        private Widgets.StatusBar status_bar;
        private Widgets.TopDisplay top_display;

        private Gtk.Button play_button;
        private Gtk.Button previous_button;
        private Gtk.Button next_button;
        private Gtk.Box action_box;

        private Views.ViewSelector view_selector;
        private Views.DnDSelection? dnd_selection = null;
        private Views.ProgressBox? progress_box = null;

        private Services.LibraryManager library_manager;

        private Enums.SourceType active_source_type;

        private bool has_music_folder {
            get {
                return settings.get_string ("music-folder") != "";
            }
        }

        private uint _active_track = 0;
        public uint active_track {
            set {
                queue_stack.select_run_row (value);
                music_stack.select_run_row (value);

                _active_track = value;

                update_title ();
            }
            get {
                return _active_track;
            }
        }

        public const string ACTION_PREFIX = "win.";
        public const string ACTION_IMPORT = "action_import";
        public const string ACTION_PLAY = "action_play";
        public const string ACTION_PLAY_NEXT = "action_play_next";
        public const string ACTION_PLAY_PREVIOUS = "action_play_previous";
        public const string ACTION_QUIT = "action_quit";
        public const string ACTION_SEARCH = "action_search";
        public const string ACTION_VIEW_ALBUMS = "action_view_albums";
        public const string ACTION_VIEW_LIST = "action_view_list";

        private const GLib.ActionEntry[] ACTION_ENTRIES = {
            { ACTION_IMPORT, action_import },
            { ACTION_PLAY, action_play, null, "false" },
            { ACTION_PLAY_NEXT, action_play_next },
            { ACTION_PLAY_PREVIOUS, action_play_previous },
            { ACTION_QUIT, action_quit },
            { ACTION_SEARCH, action_search },
            { ACTION_VIEW_ALBUMS, action_view_albums },
            { ACTION_VIEW_LIST, action_view_list }
        };

        public MainWindow (Gtk.Application application) {
            Object (application: application);

            application.set_accels_for_action (ACTION_PREFIX + ACTION_QUIT, {"<Control>q", "<Control>w"});
            application.set_accels_for_action (ACTION_PREFIX + ACTION_SEARCH, {"<Control>f"});
            application.set_accels_for_action (ACTION_PREFIX + ACTION_VIEW_ALBUMS, {"<Control>1"});
            application.set_accels_for_action (ACTION_PREFIX + ACTION_VIEW_LIST, {"<Control>2"});
        }

        construct {
            add_action_entries (ACTION_ENTRIES, this);

            settings = new GLib.Settings (Constants.APP_NAME);
            settings_ui = new GLib.Settings (Constants.APP_NAME + ".ui");

            try {
                dbus_player = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION, Constants.MPRIS_NAME, Constants.MPRIS_PATH);
                dbus_tracklist = GLib.Bus.get_proxy_sync (BusType.SESSION, Constants.MPRIS_NAME, Constants.MPRIS_PATH);
                dbus_tracklist.track_added.connect (on_track_added);
                dbus_tracklist.track_list_replaced.connect (on_track_list_replaced);
                dbus_prop = GLib.Bus.get_proxy_sync (BusType.SESSION, Constants.MPRIS_NAME, Constants.MPRIS_PATH);
                dbus_prop.properties_changed.connect (on_properties_changed);

            } catch (Error e) {
                warning (e.message);
            }

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("io/elementary/music2/application.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            library_manager = new Services.LibraryManager ();

            on_changed_source ();

            build_ui ();

            if (has_music_folder) {
                source_list_view.add_item (-1, _("Music"), Enums.Hint.MUSIC, new ThemedIcon ("library-music"));
            }
            source_list_view.add_item (1, _("Queue"), Enums.Hint.QUEUE, new ThemedIcon ("playlist-queue"));
            source_list_view.update_badge (1, 0);
            source_list_view.select_active_item (has_music_folder ? -1 : 1);

            library_manager.added_category.connect (music_stack.add_column_item);
            library_manager.cleared_library.connect (music_stack.clear_stack);
            library_manager.progress_scan.connect ((progress_val) => {
                if (progress_box != null) {
                    progress_box.update_progress (progress_val);
                }
            });
            library_manager.prepare_scan.connect (() => {
                if (progress_box != null) {
                    progress_box.destroy ();
                }

                progress_box = new Views.ProgressBox ();
                progress_box.cancelled_scan.connect (library_manager.stop_scanner);
                action_box.add (progress_box);
            });
            library_manager.loaded_category.connect (music_stack.init_selections);
            library_manager.started_scan.connect (() => {
                scans_library = true;
            });
            library_manager.finished_scan.connect ((msg) => {
                scans_library = false;

                if (progress_box != null) {
                    progress_box.cancelled_scan.disconnect (library_manager.stop_scanner);
                    progress_box.destroy ();
                    progress_box = null;
                }

                music_stack.init_selections (null);
            });
            library_manager.add_view.connect (music_stack.add_iter);

            settings.changed["source-type"].connect (on_changed_source);
            // sometimes this event is triggered at startup, which is not the desired behavior
            // settings.changed["music-folder"].connect (on_changed_folder);

            library_manager.load_library ();

            GLib.Timeout.add (Constants.INTERVAL, () => {
                if (library_manager.loaded) {
                    try {
                        dbus_player.init_player ();
                    } catch (Error e) {
                        warning (e.message);
                    }

                    init_state ();

                    if (library_manager.dirty_library ()) {
                        view_selector.sensitive = true;
                        music_stack.init_selections (null);
                    }

                    load_albums_grid ();

                    view_selector.mode_button.mode_changed.connect (on_mode_changed);

                    return false;
                }

                return true;
            });

        }

        private void build_ui () {
            height_request = 350;
            width_request = 400;
            icon_name = "multimedia-audio-player";
            title = _("Music");

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

            queue_stack = new Widgets.QueueStack ();
            queue_stack.selected_row.connect (on_selected_row);
            queue_stack.popup_media_menu.connect (on_popup_media_menu);

            music_stack = new Widgets.MusicStack (this, settings_ui);
            music_stack.selected_row.connect (on_selected_row);
            music_stack.filter_view.connect (library_manager.filter_library);
            music_stack.popup_media_menu.connect (on_popup_media_menu);

            var preferences_menuitem = new Gtk.ModelButton ();
            preferences_menuitem.text = _("Preferences");
            preferences_menuitem.clicked.connect (on_preferences_click);
            preferences_menuitem.show ();

            var menu_popover = new Gtk.Popover (null);
            menu_popover.add (preferences_menuitem);

            var menu_button = new Gtk.MenuButton ();
            menu_button.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
            menu_button.popover = menu_popover;
            menu_button.valign = Gtk.Align.CENTER;

            previous_button = new Gtk.Button.from_icon_name ("media-skip-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            previous_button.action_name = ACTION_PREFIX + ACTION_PLAY_PREVIOUS;
            previous_button.tooltip_text = _("Previous");

            play_button = new Gtk.Button ();
            play_button.action_name = ACTION_PREFIX + ACTION_PLAY;

            next_button = new Gtk.Button.from_icon_name ("media-skip-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            next_button.action_name = ACTION_PREFIX + ACTION_PLAY_NEXT;
            next_button.tooltip_text = _("Next");

            top_display = new Widgets.TopDisplay ();
            top_display.margin_start = 30;
            top_display.margin_end = 30;
            top_display.seek_position.connect (on_seek_position);
            top_display.popup_media_menu.connect (() => {
                uint[] tids = {};

                if (active_track > 0) {
                    tids += active_track;
                    on_popup_media_menu (Enums.Hint.QUEUE, tids);
                }
            });

            view_selector = new Views.ViewSelector ();
            view_selector.sensitive = false;

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

            source_list_view = new Widgets.SourceListView ();
            source_list_view.selection_changed.connect (on_selection_changed);
            source_list_view.menu_activated.connect (on_menu_activated);
            source_list_view.edited.connect (on_edited_playlist);

            action_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);

            status_bar = new Widgets.StatusBar ();
            status_bar.create_new_pl.connect (() => {});
            status_bar.show_pl_editor.connect (() => {});
            status_bar.changed_volume.connect ((new_volume) => {
                dbus_player.volume = new_volume;
            });

            var left_grid = new Gtk.Grid ();
            left_grid.orientation = Gtk.Orientation.VERTICAL;
            left_grid.add (source_list_view);
            left_grid.add (action_box);
            left_grid.add (status_bar);

            Gtk.TargetEntry target = {"text/uri-list", 0, 0};
            Gtk.drag_dest_set (left_grid, Gtk.DestDefaults.ALL, {target}, Gdk.DragAction.COPY);
            left_grid.drag_data_received.connect (on_drag_data_received);

            view_stack = new Widgets.ViewStack ();
            view_stack.add_named (queue_stack, Constants.QUEUE);
            view_stack.add_named (music_stack, "music");

            var main_hpaned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            main_hpaned.pack1 (left_grid, false, false);
            main_hpaned.pack2 (view_stack, true, false);

            settings_ui.bind ("sidebar-width", main_hpaned, "position", GLib.SettingsBindFlags.DEFAULT);
            main_hpaned.show_all ();

            add (main_hpaned);

            set_titlebar (headerbar);

            show ();
        }

        private void init_state () {
            status_bar.set_new_volume (dbus_player.volume);

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
                    switch (active_source_type) {
                        case Enums.SourceType.DIRECTORY:
                            try {
                                var tracks_meta = dbus_tracklist.get_tracks_metadata (tracks_id);
                                foreach (unowned GLib.HashTable<string, GLib.Variant> meta in tracks_meta) {
                                    on_track_added (meta);
                                }
                            } catch (Error e) {
                                warning (e.message);
                            }
                            break;
                        case Enums.SourceType.LIBRARY:
                            foreach (var tid in tracks_id) {
                                var m = library_manager.get_media (tid);
                                if (m != null) {
                                    add_to_queue (m);
                                }
                            }
                            break;

                    }
                }
            } else {
                play_button.sensitive = false;
                play_button.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            }
        }

        private void load_albums_grid () {
            if (library_manager.albums_hash.size > 0) {
                new Thread<void*> ("load_albums_grid", () => {
                    library_manager.albums_hash.foreach ((entry) => {
                        music_stack.add_grid_item (entry.value);
                        return true;
                    });

                    return null;
                });
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
            destroy ();
        }

        private void action_search () {}
        private void action_view_albums () {}
        private void action_view_list () {}
        private void action_import () {}

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
                    } else if (k == "CanGoNext" || k == "CanGoPrevious") {
                        //
                    }
                });
            }
        }

        private void on_track_added (GLib.HashTable<string, GLib.Variant> metadata, uint after_tid = 0) {
            var m = metadata_to_media (metadata);
            if (m != null) {
                add_to_queue (m);
            }
        }

        private void on_track_list_replaced (uint[] tracks, uint cur_track) {
            queue_stack.clear_stack ();

            if (tracks.length > 0) {
                switch (active_source_type) {
                    case Enums.SourceType.LIBRARY:
                        foreach (var tid in tracks) {
                            var m = library_manager.get_media (tid);
                            if (m != null) {
                                add_to_queue (m);
                            }
                        }

                        break;
                }
            } else {
                top_display.stop_progress ();
                top_display.set_visible_child_name ("empty");
                if (cur_track == 0) {
                    queue_reset = true;
                }
            }
        }

        // signals
        private void on_changed_source () {
            active_source_type = (Enums.SourceType) settings.get_enum ("source-type");
        }

        private void on_seek_position (int64 new_position) {
            try {
                dbus_player.seek (new_position);
            } catch (Error e) {
                warning (e.message);
            }
        }

        private void on_popup_media_menu (Enums.Hint hint, uint[] tids) {

        }

        private void on_preferences_click () {
            var filename = "";
            var preferences = new Dialogs.PreferencesWindow (this);
            preferences.changed_music_folder.connect ((f) => {
                filename = f;
            });
            preferences.destroy.connect (() => {
                set_music_folder (filename);
            });

            preferences.show_all ();
            preferences.run ();
        }

        private void on_mode_changed () {
            music_stack.show_view ((Enums.ViewMode) view_selector.mode_button.selected);
            source_list_view.select_active_item (-1);
        }

        private void on_selection_changed (int pid, Enums.Hint hint) {
            switch (hint) {
                case Enums.Hint.QUEUE:
                    view_stack.set_visible_child_name (Constants.QUEUE);
                    break;
                case Enums.Hint.MUSIC:
                    view_stack.set_visible_child_name ("music");
                    break;
            }
        }

        private void on_selected_row (uint row_id, Enums.SourceType activated_type) {
            if (activated_type == Enums.SourceType.QUEUE) {
                run_selected_row (row_id);
                return;
            }

            if (active_source_type != Enums.SourceType.NONE) {
                queue_reset = false;
                settings.set_enum ("source-type", Enums.SourceType.NONE);
            } else {
                queue_reset = true;
            }

            GLib.Timeout.add (Constants.INTERVAL, () => {
                if (queue_reset) {
                    queue_reset = false;

                    run_selected_row (row_id);

                    if (activated_type == Enums.SourceType.DIRECTORY) {
                        music_stack.active_album = -1;
                        settings.set_enum ("source-type", Enums.SourceType.DIRECTORY);
                    } else if (activated_type == Enums.SourceType.LIBRARY) {
                        if (scans_library) {
                            //
                        } else {
                            var f = music_stack.get_filter ((Enums.ViewMode) view_selector.mode_button.selected);
                            if (f == null) {return false;}

                            if (f.val > 0) {
                                int category_type = (int) f.field;
                                string filter_str = "";

                                if (f.field == Enums.Category.GENRE) {
                                    filter_str = library_manager.get_genre (f.val);
                                } else {
                                    filter_str = f.val.to_string ();
                                }

                                settings.set_string ("source-media", category_type.to_string () + "::" + filter_str);
                            }

                            settings.set_enum ("source-type", Enums.SourceType.LIBRARY);
                        }
                    }

                    return false;
                }

                return true;
            });
        }

        private void on_menu_activated (Views.SourceListItem item, Enums.ActionType action_type) {
            switch (item.hint) {
                case Enums.Hint.MUSIC:
                    if (action_type == Enums.ActionType.SCAN) {
                        if (active_source_type == Enums.SourceType.LIBRARY) {
                            settings.set_enum ("source-type", Enums.SourceType.NONE);
                        }

                        on_changed_folder ();
                    }
                    break;
            }
        }

        private void on_edited_playlist (int pid, string playlist_name) {

        }

        private void on_changed_folder () {
            var music_folder = settings.get_string ("music-folder");
            if (scans_library) {
                library_manager.stop_scanner ();
            }

            if (has_music_folder) {
                source_list_view.add_item (-1, _("Music"), Enums.Hint.MUSIC, new ThemedIcon ("library-music"));

                var music_dir = GLib.File.new_for_path (music_folder);
                library_manager.clear_library ();
                library_manager.scan_library (music_dir.get_uri ());

                source_list_view.select_active_item (-1);
            } else {
                source_list_view.select_active_item (1);
                source_list_view.remove_item (-1);
            }
        }

        private void on_drag_data_received (Gdk.DragContext ctx, int x, int y, Gtk.SelectionData sel, uint info, uint time) {
            var uris = sel.get_uris ();
            if (uris.length > 0) {
                var path_file = GLib.File.new_for_uri (uris[0]);
                var file_type = path_file.query_file_type (GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

                if (file_type == GLib.FileType.DIRECTORY) {
                    if (dnd_selection != null) {
                        dnd_selection.destroy ();
                        dnd_selection = null;
                    }
                    dnd_selection = new Views.DnDSelection ();
                    dnd_selection.button_clicked.connect ((btn_name) => {
                        switch (btn_name) {
                            case Enums.ActionType.PLAY:
                                settings.set_string ("source-media", uris[0]);
                                on_selected_row (0, Enums.SourceType.DIRECTORY);
                                break;
                            case Enums.ActionType.LOAD:
                                break;
                        }

                        GLib.Idle.add (() => {
                            dnd_selection.destroy ();
                            return false;
                        });
                    });

                    action_box.add (dnd_selection);
                }

                Gtk.drag_finish (ctx, true, false, time);
            }
        }

        private void changed_state (string play_state, int64 p) {
            if (p > 0) {
                top_display.set_progress (p);
            }

            var icon_name = "media-playback-start-symbolic";
            play_button.tooltip_text = _("Play");

            switch (play_state) {
                case "Playing":
                    icon_name = "media-playback-pause-symbolic";
                    play_button.tooltip_text = _("Pause");
                    play_button.sensitive = true;
                    top_display.start_progress ();
                    break;
                case "Paused":
                    top_display.pause_progress ();
                    break;
                case "Stopped":
                default:
                    top_display.stop_progress ();
                    var tid = _active_track;
                    if (tid > 0) {
                        queue_stack.remove_run_icon (tid);
                        music_stack.remove_run_icon (tid);
                    }
                    break;
            }

            play_button.image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.LARGE_TOOLBAR);
        }

        private void add_to_queue (CObjects.Media m) {
            var queue_size = queue_stack.add_iter (m);
            source_list_view.update_badge (1, queue_size);

            if (active_track >= 0 && m.tid == active_track) {
                queue_stack.select_run_row (active_track);
            }
        }

        public void set_music_folder (string new_folder) {
            if (new_folder == "" || new_folder == settings.get_string ("music-folder")) {
                return;
            }

            var context_text = "";
            if (library_manager.dirty_library ()) {
                context_text = _("Are you sure you want to set the music folder to %s? This will reset your library, remove your playlists and run the scanner.").printf ("<b>" + Markup.escape_text (new_folder) + "</b>");
            } else {
                context_text = _("You have a music folder %s. Scan this folder?").printf ("<b>" + Markup.escape_text (new_folder) + "</b>");
            }

            GLib.Idle.add (() => {
                var confirm_dialog = new Dialogs.MusicFolderConfirmation (this, context_text);
                confirm_dialog.response.connect ((response_id) => {
                    if (response_id == Gtk.ResponseType.APPLY) {
                        settings.set_string ("music-folder", new_folder);
                        on_changed_folder ();
                    }

                    confirm_dialog.destroy ();
                });

                return false;
            });
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

        private CObjects.Media? get_active_media () {
            var metadata = dbus_player.metadata;

            CObjects.Media? m = metadata_to_media (metadata);

            return m;
        }

        private void update_title () {
            if (top_display.get_visible_child_name () != "time") {
                top_display.set_visible_child_name ("time");
            }

            var m = get_active_media ();

            if (m != null) {
                top_display.set_title_markup (m);
            }
        }

        private CObjects.Media? metadata_to_media (GLib.HashTable<string, GLib.Variant> metadata) {
            if ("xesam:url" in metadata) {
                CObjects.Media m = new CObjects.Media (metadata["xesam:url"].get_string ());

                m.tid = (uint) metadata["mpris:trackid"].get_int64 ();
                m.length = (uint) metadata["mpris:length"].get_int64 ();
                m.title = metadata["xesam:title"].get_string ();
                m.album = metadata["xesam:album"].get_string ();
                var artists = metadata["xesam:artist"].get_strv ();
                m.artist = artists[0];
                var genre = metadata["xesam:genre"].get_strv ();
                m.genre = genre[0];
                m.track = (uint) metadata["xesam:trackNumber"].get_int32 ();
                m.year = metadata["music2:year"].get_uint16 (); // missing from the specification

                return m;
            }

            return null;
        }

        public override bool delete_event (Gdk.EventAny event) {
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
