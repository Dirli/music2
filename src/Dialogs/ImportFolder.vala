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
    public class Dialogs.ImportFolder : Gtk.Dialog {
        public string import_path {get; construct set;}
        public ImportFolder (Music2.MainWindow main_window, string path) {
            Object (
                border_width: 6,
                deletable: false,
                destroy_with_parent: true,
                resizable: false,
                transient_for: main_window,
                title: _("Import folder"),
                width_request: Constants.DIALOG_MIN_WIDTH,
                window_position: Gtk.WindowPosition.CENTER_ON_PARENT,
                import_path: path
            );

            var header_message = _("You plan to import a folder to your library:\n%s")
            .printf (GLib.Markup.escape_text (import_path));

            var header_label = new TitleLabel ("");
            header_label.max_width_chars = 60;
            header_label.set_markup (header_message);
            header_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);

            var simple_label = new Gtk.Label (_("Copies the folder to the music library as is. The musical contents of the folder and the structure will be saved."));
            simple_label.max_width_chars = 60;
            simple_label.wrap = true;

            var simple_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            simple_box.margin = 10;
            simple_box.add (simple_label);

            Gtk.Stack import_stack = new Gtk.Stack ();
            import_stack.expand = true;
            import_stack.add_titled (simple_box, "simple", _("As is"));

            var stack_switcher = new Gtk.StackSwitcher ();
            stack_switcher.halign = Gtk.Align.CENTER;
            stack_switcher.homogeneous = true;
            stack_switcher.stack = import_stack;

            var delete_btn = new Gtk.CheckButton.with_label (_("move imported music (delete source)"));
            main_window.settings.bind ("move-imported-music", delete_btn, "active", GLib.SettingsBindFlags.GET);
            var import_all_btn = new Gtk.CheckButton.with_label (_("import all files (not just music files)"));
            main_window.settings.bind ("import-all-files", import_all_btn, "active", GLib.SettingsBindFlags.GET);

            var layout_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            layout_box.margin = 12;
            layout_box.add (header_label);
            layout_box.add (stack_switcher);
            layout_box.add (import_stack);
            layout_box.add (delete_btn);
            layout_box.add (import_all_btn);

            var content = get_content_area () as Gtk.Box;
            content.add (layout_box);

            var close_button = add_button (_("Close"), Gtk.ResponseType.CLOSE);
            var apply_button = add_button (_("Import"), Gtk.ResponseType.APPLY);
            apply_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

            // ((Gtk.Button) close_button).clicked.connect (() => {
            //     destroy ();
            // });

            // ((Gtk.Button) apply_button).clicked.connect (() => {
            //     destroy ();
            // });
        }

        private class TitleLabel : Gtk.Label {
            public TitleLabel (string label) {
                Object (label: label);
                justify = Gtk.Justification.CENTER;
                ellipsize = Pango.EllipsizeMode.MIDDLE;
            }
        }
    }
}
