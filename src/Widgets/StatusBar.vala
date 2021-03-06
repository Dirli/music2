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
        public signal int create_new_pl (string name);
        public signal void changed_volume (double volume_value);

        private Gtk.MenuButton playlist_menubutton;
        private Gtk.MenuButton eq_menubutton;
        private Gtk.VolumeButton volume_button;

        public StatusBar () {
            var pl_button = new Gtk.ModelButton ();
            pl_button.text = _("Add Playlist");

            var pl_menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
            pl_menu_box.add (pl_button);
            pl_menu_box.show_all ();

            var pl_popover = new Gtk.Popover (null);
            pl_popover.add (pl_menu_box);

            playlist_menubutton = new Gtk.MenuButton ();
            playlist_menubutton.direction = Gtk.ArrowType.UP;
            playlist_menubutton.popover = pl_popover;
            playlist_menubutton.tooltip_text = _("Add Playlist");
            playlist_menubutton.add (new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.MENU));
            playlist_menubutton.sensitive = false;

            volume_button = new Gtk.VolumeButton ();

            var eq_popover = new Widgets.EqualizerPopover ();
            eq_popover.preset_changed.connect (update_tooltip);

            eq_menubutton = new Gtk.MenuButton ();
            eq_menubutton.popover = eq_popover;
            eq_menubutton.add (new Gtk.Image.from_icon_name ("media-eq-symbolic", Gtk.IconSize.MENU));

            eq_popover.init ();

            get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

            pack_start (playlist_menubutton);
            pack_end (eq_menubutton);
            pack_end (volume_button);

            pl_button.clicked.connect (() => {
                create_new_pl (_("New playlist"));
            });

        }

        private void on_value_changed (double new_vol) {
            changed_volume (new_vol);
        }

        public void set_new_volume (double val) {
            volume_button.value_changed.disconnect (on_value_changed);

            volume_button.set_value (val > 1.0 ? 1.0 :
                                     val < 0.0 ? 0.0 :
                                     val);

            volume_button.value_changed.connect (on_value_changed);
        }

        private void update_tooltip (string eq_preset_name) {
            eq_menubutton.tooltip_markup = _("Equalizer: %s").printf ("<b>" + Markup.escape_text (eq_preset_name) + "</b>");
        }

        public void sensitive_btns (bool val) {
            playlist_menubutton.sensitive = val;
        }
    }
}
