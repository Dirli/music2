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
            var pl_button = new Gtk.ModelButton ();
            pl_button.text = _("Add Playlist");
            var spl_button = new Gtk.ModelButton ();
            spl_button.text = _("Add Smart Playlist");

            var pl_menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            pl_menu_box.add (pl_button);
            pl_menu_box.add (spl_button);
            pl_menu_box.show_all ();

            var pl_popover = new Gtk.Popover (null);
            pl_popover.add (pl_menu_box);

            playlist_menubutton = new Gtk.MenuButton ();
            playlist_menubutton.direction = Gtk.ArrowType.UP;
            playlist_menubutton.popover = pl_popover;
            playlist_menubutton.tooltip_text = _("Add Playlist");
            playlist_menubutton.add (new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.MENU));
            playlist_menubutton.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            playlist_menubutton.sensitive = false;

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

            var eq_popover = new Widgets.EqualizerPopover ();
            eq_popover.preset_changed.connect (update_tooltip);

            eq_menubutton = new Gtk.MenuButton ();
            eq_menubutton.popover = eq_popover;
            eq_menubutton.add (new Gtk.Image.from_icon_name ("media-eq-symbolic", Gtk.IconSize.MENU));
            eq_menubutton.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

            eq_popover.init ();

            pack_start (playlist_menubutton);
            pack_end (eq_menubutton);
            pack_end (volume_menubutton);

            pl_button.clicked.connect (() => {
                create_new_pl ();
            });

            spl_button.clicked.connect (() => {
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

            if (val < 0.05) {
                icon_name = "audio-volume-muted-symbolic";
            } else if (val < 0.40) {
                icon_name = "audio-volume-low-symbolic";
            } else if (val < 0.75) {
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

        public void sensitive_btns (bool val) {
            playlist_menubutton.sensitive = val;
        }
    }
}
