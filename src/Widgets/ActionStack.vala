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
    public class Widgets.ActionStack : Gtk.Stack {
        public signal void cancelled_scan ();
        public signal void scan_library ();
        public signal void dnd_button_clicked (Enums.ActionType action_type, string uri);

        public ActionStack () {
            Object (margin_start: 5,
                    margin_end: 5);

            var empty_grid = new Gtk.Grid ();
            transition_type = Gtk.StackTransitionType.CROSSFADE;

            add_named (empty_grid, "empty");

            visible_child = empty_grid;
        }

        public void hide_widget (string widget_name) {
            var removed_widget = get_child_by_name (widget_name);
            if (removed_widget != null) {
                removed_widget.destroy ();
            }

            visible_child_name = "empty";
        }

        public void init_progress () {
            if (get_child_by_name ("progress") == null) {
                var progress_box = new Views.ProgressBox ();
                progress_box.cancelled_scan.connect (() => {
                    cancelled_scan ();
                });

                add_named (progress_box, "progress");
            }

            update_progress (0);
            set_visible_child_name ("progress");
        }

        public void init_library_folder (string box_label) {
            hide_widget ("library");

            var library_box = new Views.ScanLibraryAction (box_label);
            library_box.button_clicked.connect ((response_id) => {
                hide_widget ("library");
                if (response_id == Gtk.ResponseType.OK) {
                    scan_library ();
                }
            });

            add_named (library_box, "library");
            set_visible_child_name ("library");
        }

        public void init_dnd (Enums.SourceType source_type, string uri) {
            if (get_child_by_name ("dnd") == null) {
                var dnd_selection = new Views.DnDSelection ();
                dnd_selection.button_clicked.connect ((btn_name, uri) => {
                    hide_widget ("dnd");
                    dnd_button_clicked (btn_name, uri);
                });

                add_named (dnd_selection, "dnd");
            }

            var dnd_widget = get_child_by_name ("dnd") as Views.DnDSelection;
            if (dnd_widget != null) {
                dnd_widget.add_data (uri);
                set_visible_child_name ("dnd");
            }
        }

        public void update_progress (double progress_val) {
            var child = get_child_by_name ("progress");
            if (child != null) {
                var progress_box = child as Views.ProgressBox;
                if (progress_box != null) {
                    progress_box.update_progress (progress_val);
                }
            }
        }
    }
}
