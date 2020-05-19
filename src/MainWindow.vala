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

        private int queue_id;

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
        private Widgets.MediaMenu? media_menu = null;

        private Gtk.Button play_button;
        private Gtk.Button previous_button;
        private Gtk.Button next_button;

        private Views.ViewSelector view_selector;

        private Services.LibraryManager library_manager;
        private Services.PlaylistManager playlist_manager;

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

                var iter = library_manager.get_media_iter (value);
                if (iter != null) {
                    music_stack.select_run_row (iter);
                }

                playlist_stack.select_run_row (value);

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
        public const string ACTION_VIEW_COLUMNS = "action_view_columns";

        private const GLib.ActionEntry[] ACTION_ENTRIES = {
            { ACTION_IMPORT, action_import },
            { ACTION_PLAY, action_play, null, "false" },
            { ACTION_PLAY_NEXT, action_play_next },
            { ACTION_PLAY_PREVIOUS, action_play_previous },
            { ACTION_QUIT, action_quit },
            { ACTION_SEARCH, action_search },
            { ACTION_VIEW_ALBUMS, action_view_albums },
            { ACTION_VIEW_COLUMNS, action_view_columns }
        };

        public MainWindow (Gtk.Application application) {
            Object (application: application);

            application.set_accels_for_action (ACTION_PREFIX + ACTION_QUIT, {"<Control>q", "<Control>w"});
            application.set_accels_for_action (ACTION_PREFIX + ACTION_SEARCH, {"<Control>f"});
            application.set_accels_for_action (ACTION_PREFIX + ACTION_VIEW_ALBUMS, {"<Control>1"});
            application.set_accels_for_action (ACTION_PREFIX + ACTION_VIEW_COLUMNS, {"<Control>2"});
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
                dbus_tracklist.track_removed.connect (on_track_removed);
                dbus_prop = GLib.Bus.get_proxy_sync (BusType.SESSION, Constants.MPRIS_NAME, Constants.MPRIS_PATH);
                dbus_prop.properties_changed.connect (on_properties_changed);

            } catch (Error e) {
                warning (e.message);
            }

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("io/elementary/music2/application.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            library_manager = new Services.LibraryManager ();
            playlist_manager = new Services.PlaylistManager ();
            queue_id = playlist_manager.get_playlist_id (Constants.QUEUE);

            on_changed_source ();

            build_ui ();

            if (has_music_folder) {
                source_list_view.add_item (-1, _("Music"), Enums.Hint.MUSIC, new ThemedIcon ("library-music"));
            }
            source_list_view.add_item (queue_id, _("Queue"), Enums.Hint.QUEUE, new ThemedIcon ("playlist-queue"));
            source_list_view.update_badge (queue_id, 0);
            source_list_view.select_active_item (has_music_folder ? -1 : queue_id);

            library_manager.added_category.connect (music_stack.add_column_item);
            library_manager.cleared_library.connect (music_stack.clear_stack);
            library_manager.progress_scan.connect (action_stack.update_progress);
            library_manager.prepare_scan.connect (action_stack.init_progress);
            library_manager.started_scan.connect (() => {
                scans_library = true;
            });
            library_manager.finished_scan.connect ((msg) => {
                scans_library = false;

                action_stack.hide_widget ("progress");

                if (library_manager.dirty_library ()) {
                    view_selector.sensitive = true;

                    var iter = library_manager.get_media_iter (active_track);
                    music_stack.init_selections (iter);

                    status_bar.sensitive_btns (true);
                }
            });

            playlist_manager.add_view.connect ((tid, count) => {
                var m = library_manager.get_media (tid);
                if (m != null) {
                    m.track = count;
                    playlist_stack.add_iter (m);
                    if (active_track >= 0 && m.tid == active_track) {
                        playlist_stack.select_run_row (active_track);
                    }
                }
            });
            playlist_manager.selected_playlist.connect (on_selected_playlist);
            playlist_manager.added_playlist.connect ((pid, name, hint, icon) =>  {
                source_list_view.add_item (pid, name, hint, icon);
            });
            playlist_manager.load_playlists ();
            library_manager.init_stores ();

            settings.changed["source-type"].connect (on_changed_source);
            // sometimes this event is triggered at startup, which is not the desired behavior
            // settings.changed["music-folder"].connect (on_changed_folder);

            new Thread<void*> ("init_library", () => {
                library_manager.init_library ();
                return null;
            });

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

                        var iter = library_manager.get_media_iter (active_track);
                        music_stack.init_selections (iter);

                        status_bar.sensitive_btns (true);
                    }

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

            music_stack = new Widgets.MusicStack (this, settings_ui, library_manager.media_store, library_manager.albums_grid_store);
            music_stack.selected_row.connect (on_selected_row);
            music_stack.popup_media_menu.connect (on_popup_media_menu);

            playlist_stack = new Widgets.PlaylistStack ();
            playlist_stack.selected_row.connect (on_selected_row);
            playlist_stack.popup_media_menu.connect (on_popup_media_menu);

            var import_menuitem = new Gtk.ModelButton ();
            import_menuitem.text = _("Import to library");
            import_menuitem.clicked.connect (action_import);

            var preferences_menuitem = new Gtk.ModelButton ();
            preferences_menuitem.text = _("Preferences");
            preferences_menuitem.clicked.connect (on_preferences_click);

            var menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            menu_box.add (import_menuitem);
            menu_box.add (preferences_menuitem);
            menu_box.show_all ();

            var menu_popover = new Gtk.Popover (null);
            menu_popover.add (menu_box);

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

            top_display = new Widgets.TopDisplay (settings.get_enum ("repeat-mode"),
                                                  settings.get_enum ("shuffle-mode"));
            top_display.margin_start = 30;
            top_display.margin_end = 30;
            top_display.seek_position.connect (on_seek_position);
            top_display.mode_option_changed.connect ((key, new_val) => {
                settings.set_enum (key, new_val);
            });
            top_display.popup_media_menu.connect ((x_point, y_point) => {
                uint[] tids = {};

                if (active_track > 0) {
                    tids += active_track;
                    Gdk.Rectangle rect = {};

                    rect.x = (int) x_point;
                    rect.y = (int) y_point;
                    rect.height = 1;
                    rect.width = 1;

                    on_popup_media_menu (Enums.Hint.QUEUE, tids, rect, null);
                }
            });

            view_selector = new Views.ViewSelector ();
            view_selector.mode_button.selected = settings_ui.get_enum ("view-mode");
            view_selector.mode_button.mode_changed.connect (on_mode_changed);
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

            action_stack = new Widgets.ActionStack ();
            action_stack.margin_start = 5;
            action_stack.margin_end = 5;
            action_stack.cancelled_scan.connect (library_manager.stop_scanner);
            action_stack.dnd_button_clicked.connect (on_dnd_button_clicked);

            status_bar = new Widgets.StatusBar ();
            status_bar.create_new_pl.connect (playlist_manager.create_playlist);
            status_bar.show_pl_editor.connect (() => {});
            status_bar.changed_volume.connect ((new_volume) => {
                dbus_player.volume = new_volume;
            });

            var left_grid = new Gtk.Grid ();
            left_grid.orientation = Gtk.Orientation.VERTICAL;
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
                        case Enums.SourceType.FILE:
                            try {
                                var tracks_meta = dbus_tracklist.get_tracks_metadata (tracks_id);
                                foreach (unowned GLib.HashTable<string, GLib.Variant> meta in tracks_meta) {
                                    on_track_added (meta);
                                }
                            } catch (Error e) {
                                warning (e.message);
                            }
                            break;
                        case Enums.SourceType.PLAYLIST:
                        case Enums.SourceType.LIBRARY:
                                fill_queue (tracks_id);
                            break;
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
            destroy ();
        }

        private void action_search () {}

        private void action_import () {
            if (scans_library) {
                return;
            }

            var file_chooser = new Gtk.FileChooserNative (
                _("Import Music"),
                this,
                Gtk.FileChooserAction.SELECT_FOLDER,
                _("Open"),
                _("Cancel")
            );
            file_chooser.set_select_multiple (false);
            file_chooser.set_local_only (true);

            var select_folder = "";
            if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
                select_folder = file_chooser.get_filename ();
            }

            file_chooser.destroy ();

            if (select_folder == "") {
                return;
            }

            on_import_folder (GLib.File.new_for_path (select_folder));
        }

        private void action_view_albums () {
            view_selector.mode_button.selected = Enums.ViewMode.GRID;
        }

        private void action_view_columns () {
            view_selector.mode_button.selected = Enums.ViewMode.COLUMN;
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
            source_list_view.update_badge (queue_id, 0);
            queue_stack.clear_stack ();

            if (active_source_type == Enums.SourceType.LIBRARY || active_source_type == Enums.SourceType.PLAYLIST) {
                fill_queue (tracks);
            } else if (active_source_type == Enums.SourceType.NONE) {
                top_display.stop_progress ();
                top_display.set_visible_child_name ("empty");
                if (cur_track == 0) {
                    queue_reset = true;
                }
            }
        }

        private void on_track_removed (uint tid) {
            queue_stack.remove_iter (tid);
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

        private void on_popup_media_menu (Enums.Hint hint, uint[] tids, Gdk.Rectangle rect, Gtk.Widget? w) {
            if (media_menu == null) {
                media_menu = new Widgets.MediaMenu ();
                media_menu.popdown ();
                media_menu.activate_menu_item.connect (on_activate_item);
            }

            if (hint == Enums.Hint.NONE) {
                return;
            }

            media_menu.active_media = active_track > 0;

            media_menu.set_pointing_to (rect);
            media_menu.set_relative_to (w == null ? top_display : w);
            media_menu.popup_media_menu (hint, tids, w == null);
        }

        private void on_activate_item (Enums.Hint hint, Enums.ActionType action_type, uint[] tids) {
            if (tids.length == 0) {
                return;
            }

            switch (action_type) {
                case Enums.ActionType.BROWSE:
                    show_in_browser (hint, tids[0]);
                    break;
                case Enums.ActionType.REMOVE:
                    var view_name = view_stack.get_visible_child_name ();
                    if (view_name != null) {
                        switch (view_name) {
                            case Constants.QUEUE:
                                try {
                                    dbus_tracklist.remove_track (tids[0]);
                                } catch (Error e) {
                                    warning (e.message);
                                }
                                break;
                            case "playlist":
                                //
                                break;
                            case "music":
                                //
                                break;

                        }
                    }

                    break;
                case Enums.ActionType.SCROLL:
                    var visible_widget = view_stack.get_visible_child ();
                    if (visible_widget is Widgets.MusicStack) {
                        var stack_wrapper = visible_widget as Interfaces.StackWrapper;
                        if (stack_wrapper != null) {
                            var iter = library_manager.get_media_iter (active_track);
                            if (iter != null) {
                                stack_wrapper.scroll_to_current (iter);
                            }
                        }
                    } else if (visible_widget is Interfaces.ListStack) {
                        var list_stack = visible_widget as Interfaces.ListStack;
                        if (list_stack != null) {
                            list_stack.scroll_to_current (active_track);
                        }
                    }

                    break;
            }
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

        private void on_import_folder (GLib.File folder) {
            GLib.Timeout.add (400, () => {
                if (folder.query_exists ()) {
                    var music_folder = settings.get_string ("music-folder");
                    var import_dialog = new Dialogs.ImportFolder (this, folder.get_path ());
                    import_dialog.response.connect ((response_id) => {
                        if (response_id == Gtk.ResponseType.APPLY) {
                            new Thread<void*> ("import_folder", () => {
                                library_manager.import_folder (folder.get_uri (), music_folder);
                                return null;
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
            switch (hint) {
                case Enums.Hint.QUEUE:
                    view_stack.set_visible_child_name (Constants.QUEUE);
                    break;
                case Enums.Hint.PLAYLIST:
                    playlist_manager.select_playlist (pid, hint);
                    view_stack.set_visible_child_name ("playlist");
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
                active_source_type = Enums.SourceType.NONE;
                settings.set_enum ("source-type", Enums.SourceType.NONE);
            } else {
                queue_reset = true;
            }

            GLib.Timeout.add (Constants.INTERVAL, () => {
                if (queue_reset) {
                    queue_reset = false;

                    run_selected_row (row_id);

                    if (activated_type != Enums.SourceType.LIBRARY) {
                        music_stack.active_album = -1;
                    }

                    if (activated_type == Enums.SourceType.LIBRARY) {
                        if (scans_library) {
                            return false;
                        } else {
                            var f = music_stack.get_filter ((Enums.ViewMode) view_selector.mode_button.selected);
                            if (f == null) {return false;}

                            if (f.id > 0) {
                                int category_type = (int) f.category;
                                string filter_str = f.category == Enums.Category.GENRE ? f.str : f.id.to_string ();

                                settings.set_string ("source-media", category_type.to_string () + "::" + filter_str);
                            }
                        }
                    } else if (activated_type == Enums.SourceType.PLAYLIST) {
                        if (playlist_manager.modified_pid == playlist_stack.pid) {
                            playlist_manager.update_playlist (playlist_manager.modified_pid, true);
                            if (playlist_manager.modified_pid != 0) {
                                return true;
                            }
                        }

                        settings.set_string ("source-media", playlist_stack.pid.to_string ());
                    }
                    active_source_type = activated_type;
                    settings.set_enum ("source-type", activated_type);

                    return false;
                }

                return true;
            });
        }

        private void on_menu_activated (Views.SourceListItem item, Enums.ActionType action_type) {
            switch (action_type) {
                case Enums.ActionType.SCAN:
                    if (item.hint == Enums.Hint.MUSIC) {
                        on_changed_folder ();
                    }
                    break;
                case Enums.ActionType.CLEAR:
                    if (item.hint == Enums.Hint.QUEUE) {
                        settings.set_enum ("source-type", Enums.SourceType.NONE);
                    }
                    break;
                case Enums.ActionType.SAVE:
                    if (item.hint == Enums.Hint.QUEUE) {
                        if (active_source_type == Enums.SourceType.LIBRARY
                         || active_source_type == Enums.SourceType.PLAYLIST) {
                            var pid = playlist_manager.create_playlist (_("Queue"));
                            if (pid > 0) {
                                try {
                                    var tracks = dbus_tracklist.get_tracklist ();
                                    foreach (var tid in tracks) {
                                        playlist_manager.add_to_playlist (pid, tid);
                                    }
                                } catch (Error e) {
                                    warning (e.message);
                                }
                            }
                        }
                    }
                    break;
                case Enums.ActionType.REMOVE:
                    if (item.hint == Enums.Hint.PLAYLIST) {
                        var pid = item.pid;
                        if (pid != queue_id && playlist_manager.remove_playlist (pid)) {
                            source_list_view.remove_item (pid);
                        }
                    }
                    break;
                case Enums.ActionType.EXPORT:
                    export_playlist (item);
                    break;

            }
        }

        private void on_selected_playlist (int pid, Enums.Hint playlist_hint, Enums.SourceType playlist_type) {
            if (playlist_stack.pid != pid) {
                playlist_stack.init_store (pid, playlist_hint, playlist_type);
            }
        }

        private void on_edited_playlist (int pid, string playlist_name) {
            if (queue_id != pid) {
                var modified_name = playlist_manager.edit_playlist (pid, playlist_name);
                if (modified_name != "") {
                    source_list_view.rename_playlist (pid, modified_name);
                }
            }
        }

        private void on_changed_folder () {
            var music_folder = settings.get_string ("music-folder");
            if (scans_library) {
                return;
            }

            if (library_manager.dirty_library ()) {
                library_manager.clear_library ();
                view_selector.sensitive = false;
                status_bar.sensitive_btns (false);
            }

            if (active_source_type == Enums.SourceType.LIBRARY) {
                settings.set_enum ("source-type", Enums.SourceType.NONE);
            }

            if (has_music_folder) {
                source_list_view.add_item (-1, _("Music"), Enums.Hint.MUSIC, new ThemedIcon ("library-music"));

                var music_dir = GLib.File.new_for_path (music_folder);
                new Thread<void*> ("scan_directory", () => {
                    library_manager.scan_library (music_dir.get_uri ());
                    return null;
                });

                source_list_view.select_active_item (-1);
            } else {
                source_list_view.select_active_item (1);
                source_list_view.remove_item (-1);
            }
        }

        private void on_dnd_button_clicked (Enums.ActionType action_type, string uri) {
            switch (action_type) {
                case Enums.ActionType.PLAY:
                    source_list_view.select_active_item (queue_id);
                    settings.set_string ("source-media", uri);
                    on_selected_row (0, Enums.SourceType.DIRECTORY);
                    break;
                case Enums.ActionType.IMPORT:
                    if (scans_library) {
                        return;
                    }

                    on_import_folder (GLib.File.new_for_uri (uri));
                    break;
            }
        }

        private void on_drag_data_received (Gdk.DragContext ctx, int x, int y, Gtk.SelectionData sel, uint info, uint time) {
            var uris = sel.get_uris ();
            if (uris.length > 0) {
                var path_file = GLib.File.new_for_uri (uris[0]);
                var file_type = path_file.query_file_type (GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

                if (file_type == GLib.FileType.DIRECTORY) {
                    action_stack.init_dnd (Enums.SourceType.DIRECTORY, uris[0]);
                } else if (file_type == GLib.FileType.REGULAR) {
                    var file_name = path_file.get_basename ();
                    if (file_name != null) {
                        if (file_name.has_suffix (".m3u")) {
                            settings.set_string ("source-media", uris[0]);

                            on_selected_row (0, Enums.SourceType.EXTPLAYLIST);
                        }
                    }
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
                    if (settings.get_enum ("repeat-mode") != Enums.RepeatMode.MEDIA) {
                        top_display.stop_progress ();
                        var tid = _active_track;
                        if (tid > 0) {
                            queue_stack.remove_run_icon (tid);

                            var iter = library_manager.get_media_iter (tid);
                            if (iter != null) {
                                music_stack.remove_run_icon (iter);
                            }

                            playlist_stack.remove_run_icon (tid);
                        }
                    }
                    break;
            }

            play_button.image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.LARGE_TOOLBAR);
        }

        private void fill_queue (owned uint[] tids) {
            new Thread<void*> ("fill_queue", () => {
                foreach (var tid in tids) {
                    var m = library_manager.get_media (tid);
                    if (m != null) {
                        // var queue_size = queue_stack.add_iter (m);
                        // source_list_view.update_badge (queue_id, queue_size);
                        //
                        // if (active_track >= 0 && m.tid == active_track) {
                        //     queue_stack.select_run_row (active_track);
                        // }
                        add_to_queue (m);
                    }
                }

                return null;
            });
        }

        private void add_to_queue (CObjects.Media m) {
            var queue_size = queue_stack.add_iter (m);
            source_list_view.update_badge (queue_id, queue_size);

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

        private void show_in_browser (Enums.Hint hint, uint tid) {
            CObjects.Media? media = null;
            if (Enums.Hint.QUEUE == hint) {
                try {
                    uint[] tids = {tid};
                    var tracks_meta = dbus_tracklist.get_tracks_metadata (tids);
                    if (tracks_meta.length > 0) {
                        media = metadata_to_media (tracks_meta[0]);
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            } else if (Enums.Hint.MUSIC == hint) {
                media = library_manager.get_media (tid);
            }

            if (media != null) {
                try {
                    var m_file = GLib.File.new_for_uri (media.uri);
                    Gtk.show_uri (null, m_file.get_parent ().get_uri (), Gdk.CURRENT_TIME);
                } catch (Error err) {
                    warning ("Could not browse media %s: %s\n", media.uri, err.message);
                }
            }
        }

        private void export_playlist (Views.SourceListItem item) {
            var path = Tools.GuiUtils.get_playlist_path (item.name, settings.get_string ("music-folder"));
            var hint = item.hint;
            var pid = item.pid;

            new Thread<void*> ("export_playlist", () => {
                CObjects.Media[] tracks = {};
                if (hint == Enums.Hint.QUEUE) {
                    try {
                        var tids = dbus_tracklist.get_tracklist ();
                        if (active_source_type == Enums.SourceType.DIRECTORY || active_source_type == Enums.SourceType.EXTPLAYLIST || active_source_type == Enums.SourceType.FILE) {
                            var tracks_meta = dbus_tracklist.get_tracks_metadata (tids);
                            foreach (unowned GLib.HashTable<string, GLib.Variant> meta in tracks_meta) {
                                var m = metadata_to_media (meta);
                                if (m != null) {
                                    tracks += m;
                                }
                            }
                        } else {
                            foreach (var tid in tids) {
                                var m = library_manager.get_media (tid);
                                if (m != null) {
                                    tracks += m;
                                }
                            }
                        }
                    } catch (Error e) {
                        warning (e.message);
                    }
                } else if (hint == Enums.Hint.PLAYLIST) {
                    var tids = playlist_manager.get_playlist (pid);
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
                    Tools.FileUtils.save_playlist_m3u (path, tracks);
                }

                return null;
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
            playlist_manager.update_playlist_sync ();
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
