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
    public class Views.AlbumView : Gtk.Grid {
        public signal void selected_row (uint row_id);

        private Gtk.Window parent_window;

        private Gtk.TreeSelection tree_sel;

        public Gtk.TreeView tracks_view;
        private Structs.Album? current_album = null;
        private Views.AlbumImage album_cover;
        private Gtk.Label album_label;

        private Gtk.Menu cover_action_menu;

        public AlbumView (Gtk.Window p) {
            parent_window = p;
            album_cover = new Views.AlbumImage ();
            album_cover.width_request = 184;
            album_cover.margin = 28;
            album_cover.margin_bottom = 12;

            var cover_event_box = new Gtk.EventBox ();
            cover_event_box.add (album_cover);

            var cover_set_new = new Gtk.MenuItem.with_label (_("Set new album cover"));

            cover_action_menu = new Gtk.Menu ();
            cover_action_menu.append (cover_set_new);
            cover_action_menu.show_all ();

            album_label = new Gtk.Label ("");
            album_label.halign = Gtk.Align.START;
            album_label.margin_start = album_label.margin_end = 28;
            album_label.max_width_chars = 30;
            album_label.wrap = true;
            album_label.xalign = 0;
            album_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

            tracks_view = new LViews.ListView (Enums.Hint.ALBUM_LIST);
            tracks_view.expand = true;
            tracks_view.headers_visible = false;
            tracks_view.set_tooltip_column ((int) Enums.ListColumn.ARTIST);
            tracks_view.get_style_context ().remove_class (Gtk.STYLE_CLASS_VIEW);
            tracks_view.set_model (new Gtk.ListStore.newv (Enums.ListColumn.get_all ()));

            var tracks_scrolled = new Gtk.ScrolledWindow (null, null);
            tracks_scrolled.margin_top = 18;
            tracks_scrolled.add (tracks_view);

            attach (cover_event_box, 0, 0, 1, 1);
            attach (album_label,     0, 1, 1, 1);
            attach (tracks_scrolled, 0, 2, 1, 1);

            tree_sel = tracks_view.get_selection ();

            tracks_view.row_activated.connect (on_row_activated);
            cover_event_box.button_press_event.connect (show_cover_context_menu);
            cover_set_new.activate.connect (set_new_cover);
        }

        protected void on_row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {
            var tree_model = tracks_view.get_model ();
            if (tree_model == null) {
                return;
            }

            Gtk.TreeIter? iter;
            tree_model.get_iter (out iter, path);

            if (iter != null) {
                uint tid;
                tree_model.@get (iter, (int) Enums.ListColumn.TRACKID, out tid, -1);
                selected_row (tid);
            }
        }

        public bool show_cover_context_menu (Gdk.EventButton e) {
            if (e.button == Gdk.BUTTON_SECONDARY) {
                cover_action_menu.popup_at_pointer (e);
            }
            return true;
        }

        public Gtk.TreeModel? get_model () {
            return tracks_view.get_model ();
        }

        public Gee.ArrayQueue<uint> get_tracks () {
            var tracks = new Gee.ArrayQueue<uint> ();
            var tree_model = get_model ();
            if (tree_model != null) {
                tree_model.@foreach ((model, path, iter) => {
                    uint tid;
                    tree_model.@get (iter, (int) Enums.ListColumn.TRACKID, out tid, -1);

                    tracks.offer (tid);

                    return false;
                });
            }

            return tracks;
        }

        public void clear () {
            current_album = null;
            album_label.set_label ("");

            var tree_model = get_model ();
            if (tree_model != null) {
                ((Gtk.ListStore) tree_model).clear ();
            }
        }

        public bool set_album (Structs.Album album_struct) {
            if (current_album != null && album_struct.album_id == current_album.album_id) {
                return false;
            }

            clear ();

            current_album = album_struct;
            album_label.set_label (album_struct.title);

            album_cover.image.gicon = Tools.GuiUtils.get_cover_icon (album_struct.year, album_struct.title);
            return true;
        }

        private void set_new_cover () {
            var image_filter = new Gtk.FileFilter ();
            image_filter.set_filter_name (_("Image files"));
            image_filter.add_mime_type ("image/*");

            var file = new Gtk.FileChooserNative (
                _("Open"),
                parent_window,
                Gtk.FileChooserAction.OPEN,
                _("_Open"),
                _("_Cancel")
            );
            file.add_filter (image_filter);

            if (file.run () == Gtk.ResponseType.ACCEPT) {
                if (Tools.FileUtils.save_cover_file (file.get_file (), current_album.year, current_album.title)) {
                    album_cover.image.gicon = Tools.GuiUtils.get_cover_icon (current_album.year, current_album.title);
                }
            }

            file.destroy ();
        }

        public void unselect_rows () {
            tree_sel.unselect_all ();
        }

        public void select_run_row (Gtk.TreeIter child_iter) {
            GLib.Idle.add (() => {
                Gtk.TreeIter? iter = null;
                Gtk.TreePath? sel_path = null;
                var tree_model = tracks_view.get_model ();
                if (tree_model != null) {
                    var filter_model = tree_model as Gtk.TreeModelFilter;
                    if (filter_model != null && filter_model.convert_child_iter_to_iter (out iter, child_iter)) {
                        if (iter != null) {
                            sel_path = filter_model.get_path (iter);
                        }
                    }
                }

                if (sel_path != null) {
                    tracks_view.set_cursor (sel_path, null, false);
                }

                return false;
            });
        }
    }
}
