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
    public class Dialogs.MusicFolderConfirmation : Gtk.Dialog {
        public MusicFolderConfirmation (Music2.MainWindow main_window, string context_text) {
            Object (
                border_width: 6,
                deletable: false,
                destroy_with_parent: true,
                resizable: false,
                transient_for: main_window,
                width_request: Constants.DIALOG_MIN_WIDTH,
                window_position: Gtk.WindowPosition.CENTER_ON_PARENT
            );

            modal = true;

            var image = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.DIALOG);
            image.valign = Gtk.Align.CENTER;

            var primary_label = new Gtk.Label (_("Set Music Folder?"));
            primary_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);
            primary_label.hexpand = true;
            primary_label.max_width_chars = 50;
            primary_label.wrap = true;
            primary_label.xalign = 0;

            var secondary_label = new Gtk.Label (null);
            secondary_label.max_width_chars = 50;
            secondary_label.use_markup = true;
            secondary_label.wrap = true;
            secondary_label.xalign = 0;
            secondary_label.label = context_text;

            var layout = new Gtk.Grid ();
            layout.column_spacing = 12;
            layout.margin = 6;
            layout.row_spacing = 6;
            layout.attach (image, 0, 0, 1, 2);
            layout.attach (primary_label, 1, 0);
            layout.attach (secondary_label, 1, 1);

            var content = get_content_area () as Gtk.Box;
            content.add (layout);

            add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
            var ok = (Gtk.Button) add_button (_("Ok"), Gtk.ResponseType.APPLY);
            ok.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

            show_all ();
        }
    }
}
