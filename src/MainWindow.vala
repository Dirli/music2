namespace Music2 {
    public class MainWindow : Gtk.ApplicationWindow {
        private GLib.Settings settings_ui;
        private GLib.Settings settings;

        private PlayerIface? dbus_player = null;
        private TrackListIface? dbus_tracklist = null;
        private DbusPropIface? dbus_prop = null;

        private Widgets.SourceListView source_list_view;

        private Gtk.Button play_button;
        private Gtk.Button previous_button;
        private Gtk.Button next_button;

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

            build_ui ();
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

            var preferences_menuitem = new Gtk.MenuItem.with_label (_("Preferences"));
            preferences_menuitem.activate.connect (on_preferences_click);

            var menu = new Gtk.Menu ();
            menu.append (preferences_menuitem);
            menu.show_all ();

            var menu_button = new Gtk.MenuButton ();
            menu_button.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
            menu_button.popup = menu;
            menu_button.valign = Gtk.Align.CENTER;

            previous_button = new Gtk.Button.from_icon_name ("media-skip-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            previous_button.action_name = ACTION_PREFIX + ACTION_PLAY_PREVIOUS;
            previous_button.tooltip_text = _("Previous");

            play_button = new Gtk.Button ();
            play_button.action_name = ACTION_PREFIX + ACTION_PLAY;

            next_button = new Gtk.Button.from_icon_name ("media-skip-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            next_button.action_name = ACTION_PREFIX + ACTION_PLAY_NEXT;
            next_button.tooltip_text = _("Next");

            var headerbar = new Gtk.HeaderBar ();
            headerbar.show_close_button = true;
            headerbar.pack_start (previous_button);
            headerbar.pack_start (play_button);
            headerbar.pack_start (next_button);
            headerbar.pack_end (menu_button);
            headerbar.set_title (_("Music"));
            headerbar.show_all ();

            source_list_view = new Widgets.SourceListView ();
            source_list_view.selection_changed.connect (on_selection_changed);
            source_list_view.menu_activated.connect (on_menu_activated);
            source_list_view.edited.connect (on_edited_playlist);

            var left_grid = new Gtk.Grid ();
            left_grid.orientation = Gtk.Orientation.VERTICAL;
            left_grid.add (source_list_view);

            var main_hpaned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            main_hpaned.pack1 (left_grid, false, false);

            settings_ui.bind ("sidebar-width", main_hpaned, "position", GLib.SettingsBindFlags.DEFAULT);
            main_hpaned.show_all ();

            add (main_hpaned);

            set_titlebar (headerbar);

            show ();
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

        }

        private void on_track_added (GLib.HashTable<string, GLib.Variant> metadata, uint after_tid = 0) {

        }

        private void on_track_list_replaced (uint[] tracks, uint cur_track) {

        }

        // signals
        private void on_preferences_click () {

        }

        private void on_selection_changed (int pid, Enums.Hint hint) {

        }

        private void on_menu_activated (Views.SourceListItem item, string action_name) {

        }

        private void on_edited_playlist (int pid, string playlist_name) {
            
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
