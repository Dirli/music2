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
    public class Views.SourceListItem : Granite.Widgets.SourceList.Item,
                                        Granite.Widgets.SourceListDragDest {
        public signal void menu_item_activated (Views.SourceListItem menu_item, Enums.ActionType action_type);

        public int pid { get; construct; }
        public Enums.Hint hint { get; construct; }
        public GLib.Icon? activatable_icon { get; construct; }
        private Gtk.Menu playlist_menu;

        public SourceListItem (int p_id, string name, Enums.Hint hint, GLib.Icon icon, GLib.Icon? activatable_icon = null) {
            Object (activatable_icon: activatable_icon,
                    hint: hint,
                    icon: icon,
                    name: name,
                    pid: p_id);
        }

        construct {
            playlist_menu = new Gtk.Menu ();

            switch (hint) {
                case Enums.Hint.PLAYLIST:
                    var playlist_rename = new Gtk.MenuItem.with_label (_("Rename"));
                    var playlist_remove = new Gtk.MenuItem.with_label (_("Remove"));
                    var playlist_export = new Gtk.MenuItem.with_label (_("Export…"));
                    var playlist_clear = new Gtk.MenuItem.with_label (_("Clear…"));

                    playlist_menu.append (playlist_rename);
                    playlist_menu.append (playlist_remove);
                    playlist_menu.append (playlist_export);
                    playlist_menu.append (playlist_clear);
                    playlist_rename.activate.connect (() => {menu_item_activated (this, Enums.ActionType.RENAME);});
                    playlist_remove.activate.connect (() => {menu_item_activated (this, Enums.ActionType.REMOVE);});
                    playlist_export.activate.connect (() => {menu_item_activated (this, Enums.ActionType.EXPORT);});
                    playlist_clear.activate.connect (() => {menu_item_activated (this, Enums.ActionType.CLEAR);});
                    break;
                case Enums.Hint.EXTERNAL_PLAYLIST:
                    var playlist_rename = new Gtk.MenuItem.with_label (_("Rename"));
                    var playlist_remove = new Gtk.MenuItem.with_label (_("Remove"));                    

                    playlist_menu.append (playlist_rename);
                    playlist_menu.append (playlist_remove);
                    playlist_rename.activate.connect (() => {menu_item_activated (this, Enums.ActionType.RENAME);});
                    playlist_remove.activate.connect (() => {menu_item_activated (this, Enums.ActionType.REMOVE);});
                    break;
                case Enums.Hint.SMART_PLAYLIST:
                    // var playlist_rename = new Gtk.MenuItem.with_label (_("Rename"));
                    var playlist_edit = new Gtk.MenuItem.with_label (_("Edit…"));
                    // var playlist_remove = new Gtk.MenuItem.with_label (_("Remove"));
                    var playlist_export = new Gtk.MenuItem.with_label (_("Export…"));

                    // playlist_menu.append (playlist_rename);
                    playlist_menu.append (playlist_edit);
                    // playlist_menu.append (playlist_remove);
                    playlist_menu.append (playlist_export);

                    // playlist_rename.activate.connect (() => {menu_item_activated (this, Enums.ActionType.RENAME);});
                    playlist_edit.activate.connect (() => {menu_item_activated (this, Enums.ActionType.EDIT);});
                    // playlist_remove.activate.connect (() => {menu_item_activated (this, Enums.ActionType.REMOVE);});
                    playlist_export.activate.connect (() => {menu_item_activated (this, Enums.ActionType.EXPORT);});
                    break;
                case Enums.Hint.QUEUE:
                    var playlist_save = new Gtk.MenuItem.with_label (_("Save as Playlist"));
                    playlist_menu.append (playlist_save);
                    var playlist_export = new Gtk.MenuItem.with_label (_("Export…"));
                    playlist_menu.append (playlist_export);
                    var playlist_clear = new Gtk.MenuItem.with_label (_("Clear…"));
                    playlist_menu.append (playlist_clear);
                    playlist_save.activate.connect (() => {menu_item_activated (this, Enums.ActionType.SAVE);});
                    playlist_export.activate.connect (() => {menu_item_activated (this, Enums.ActionType.EXPORT);});
                    playlist_clear.activate.connect (() => {menu_item_activated (this, Enums.ActionType.CLEAR);});
                    break;
                case Enums.Hint.MUSIC:
                    var full_scan = new Gtk.MenuItem.with_label (_("Scan music library"));
                    playlist_menu.append (full_scan);
                    full_scan.activate.connect (() => {menu_item_activated (this, Enums.ActionType.SCAN);});
                    break;
            }

            playlist_menu.show_all ();
        }

        public override Gtk.Menu? get_context_menu () {
            if (playlist_menu != null) {
                if (playlist_menu.get_attach_widget () != null) {
                    playlist_menu.detach ();
                }
                return playlist_menu;
            }
            return null;
        }

        private bool data_drop_possible (Gdk.DragContext context, Gtk.SelectionData data) {
            return hint == Enums.Hint.PLAYLIST && data.get_target () == Gdk.Atom.intern_static_string ("text/uri-list");
        }

        private Gdk.DragAction data_received (Gdk.DragContext context, Gtk.SelectionData data) {
            return Gdk.DragAction.COPY;
        }
    }
}
