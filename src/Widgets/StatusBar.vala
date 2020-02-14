namespace Music2 {
    public class Widgets.StatusBar : Gtk.ActionBar {
        public signal void create_new_pl ();
        public signal void show_pl_editor ();
        public signal void changed_volume (double volume_value);

        private Gtk.MenuButton playlist_menubutton;
        private Gtk.MenuButton eq_menubutton;
        private Gtk.MenuButton volume_menubutton;
        private Gtk.Image volume_icon;
        private Gtk.Scale volume_scale;

        public StatusBar () {
            var add_pl_menuitem = new Gtk.MenuItem.with_label (_("Add Playlist"));
            var add_spl_menuitem = new Gtk.MenuItem.with_label (_("Add Smart Playlist"));

            var menu = new Gtk.Menu ();
            menu.append (add_pl_menuitem);
            menu.append (add_spl_menuitem);
            menu.show_all ();

            playlist_menubutton = new Gtk.MenuButton ();
            playlist_menubutton.direction = Gtk.ArrowType.UP;
            playlist_menubutton.popup = menu;
            playlist_menubutton.tooltip_text = _("Add Playlist");
            playlist_menubutton.add (new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.MENU));
            playlist_menubutton.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

            volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 5);
            volume_scale.hexpand = true;

            var volume_layout = new Gtk.Grid ();
            volume_layout.margin = 8;
            volume_layout.orientation = Gtk.Orientation.HORIZONTAL;
            volume_layout.row_spacing = 12;

            volume_layout.add (volume_scale);
            volume_layout.show_all ();

            var volume_popover = new Gtk.Popover (null);
            volume_popover.width_request = 200;
            volume_popover.add (volume_layout);

            volume_icon = new Gtk.Image ();

            volume_menubutton = new Gtk.MenuButton ();
            volume_menubutton.popover = volume_popover;
            volume_menubutton.add (volume_icon);
            volume_menubutton.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

            eq_menubutton = new Gtk.MenuButton ();
            eq_menubutton.add (new Gtk.Image.from_icon_name ("media-eq-symbolic", Gtk.IconSize.MENU));
            eq_menubutton.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

            pack_start (playlist_menubutton);
            pack_end (eq_menubutton);
            pack_end (volume_menubutton);

            add_pl_menuitem.activate.connect (() => {
                create_new_pl ();
            });

            add_spl_menuitem.activate.connect (() => {
                show_pl_editor ();
            });
        }

        private void on_value_changed () {
            double val = volume_scale.get_value ();
            changed_volume (val / 100);
        }

        public void set_new_volume (double val) {
            volume_scale.value_changed.disconnect (on_value_changed);

            string icon_name = "audio-volume-muted-symbolic";

            volume_scale.set_value (val * 100);

            if (val < 0.10) {
                icon_name = "audio-volume-muted-symbolic";
            } else if (val < 0.45) {
                icon_name = "audio-volume-low-symbolic";
            } else if (val < 0.90) {
                icon_name = "audio-volume-medium-symbolic";
            } else {
                icon_name = "audio-volume-high-symbolic";
            }
            volume_icon.set_from_icon_name (icon_name, Gtk.IconSize.MENU);
            volume_menubutton.tooltip_text = "%.0lf".printf (val * 100);

            volume_scale.value_changed.connect (on_value_changed);
        }

        private void update_tooltip (string eq_preset_name) {
            eq_menubutton.tooltip_markup = _("Equalizer: %s").printf ("<b>" + Markup.escape_text (eq_preset_name) + "</b>");
        }
    }
}
