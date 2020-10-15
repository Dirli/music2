namespace Music2 {
    public class Widgets.MenuPopover : Gtk.Popover {
        public MenuPopover () {
            var import_btn = new Gtk.Button ();
            import_btn.set_action_name (Constants.ACTION_PREFIX + Constants.ACTION_IMPORT);
            import_btn.add (
                new Granite.AccelLabel.from_action_name (
                    _("Import to library"),
                    import_btn.action_name
                )
            );
            import_btn.clicked.connect (() => {
                popdown ();
            });

            var pref_btn = new Gtk.Button ();
            pref_btn.set_action_name (Constants.ACTION_PREFIX + Constants.ACTION_PREFERENCES);
            pref_btn.add (
                new Granite.AccelLabel.from_action_name (
                    _("Preferences"),
                    pref_btn.action_name
                )
            );
            pref_btn.clicked.connect (() => {
                popdown ();
            });

            var about_btn = new Gtk.Button ();
            about_btn.label = _("About");
            about_btn.clicked.connect (() => {
                popdown ();
                var about = new Dialogs.About ();
                about.run ();
            });

            var menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            menu_box.margin = 10;
            menu_box.add (import_btn);
            menu_box.add (pref_btn);
            menu_box.add (about_btn);
            menu_box.show_all ();

            add (menu_box);
        }
    }
}
