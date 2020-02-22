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
        public Gtk.ListStore tracks_store;
        private Gee.HashMap<uint, Gtk.TreeIter?> tracks_hash;

        private Gtk.TreeSelection tree_sel;

        public int active_album_id {
            get {
                if (current_album == null) {
                    return -1;
                }

                return current_album.album_id;
            }
        }

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

            tracks_hash = new Gee.HashMap<uint, Gtk.TreeIter?> ();

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

            tracks_store = new Gtk.ListStore.newv (Enums.ListColumn.get_all ());

            var tracks_view = new LViews.ListView (Enums.Hint.ALBUM_LIST);
            tracks_view.expand = true;
            tracks_view.headers_visible = false;
            tracks_view.set_tooltip_column (Enums.ListColumn.ARTIST);
            tracks_view.set_model (tracks_store);
            tracks_view.get_style_context ().remove_class (Gtk.STYLE_CLASS_VIEW);

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
            Gtk.TreeIter? iter;
            tracks_store.get_iter (out iter, path);

            if (iter != null) {
                uint tid;
                tracks_store.@get (iter, Enums.ListColumn.TRACKID, out tid);
                selected_row (tid);
            }
        }

        public bool show_cover_context_menu (Gdk.EventButton e) {
            if (e.button == Gdk.BUTTON_SECONDARY) {
                cover_action_menu.popup_at_pointer (e);
            }
            return true;
        }

        private void reset () {
            current_album = null;
            tracks_store.clear ();
            tracks_hash.clear ();
            album_label.set_label ("");
            // exist_cover = false;
        }

        public void add_track (CObjects.Media m) {
            GLib.Mutex mutex = GLib.Mutex ();
            mutex.lock ();

            Gtk.TreeIter iter;
            tracks_store.insert_with_values (out iter, -1,
                                             Enums.ListColumn.TRACKID, m.tid,
                                             Enums.ListColumn.TITLE, m.title,
                                             Enums.ListColumn.ARTIST, m.artist,
                                             Enums.ListColumn.LENGTH, m.length);

            tracks_hash[m.tid] = iter;
            mutex.unlock ();
        }

        public void set_album (Structs.Album album_struct) {
            reset ();

            current_album = album_struct;
            album_label.set_label (album_struct.title);

            album_cover.image.gicon = Tools.GuiUtils.get_cover_icon (album_struct.year, album_struct.title);
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

        public void remove_run_icon (uint tid) {
            if (tracks_hash.has_key (tid)) {
                tracks_store.set (tracks_hash[tid], Enums.ListColumn.ICON, null, -1);

                Gtk.TreeModel mod;
                var paths_list = tree_sel.get_selected_rows (out mod);

                if (paths_list.length () > 0) {
                    tree_sel.unselect_path (paths_list.nth_data (0));
                }
            }
        }

        public void select_run_row (uint tid) {
            if (tracks_hash.has_key (tid)) {
                GLib.Idle.add (() => {
                    var iter = tracks_hash[tid];
                    tree_sel.select_iter (iter);
                    var scr_win = get_child_at (0, 2);
                    if (scr_win is Gtk.ScrolledWindow) {
                        var tree_view = (scr_win as Gtk.ScrolledWindow).get_child ();
                        if (tree_view != null && tree_view is Gtk.TreeView) {
                            Gtk.TreeModel mod;
                            var paths_list = tree_sel.get_selected_rows (out mod);
                            if (paths_list.length () > 0) {
                                tracks_store.set (iter, Enums.ListColumn.ICON, new GLib.ThemedIcon ("audio-volume-high-symbolic"), -1);
                                var column = (tree_view as Gtk.TreeView).get_column (0);
                                if (column != null) {
                                    var cells = column.get_cells ();
                                    if (cells.length () > 0) {
                                        (tree_view as Gtk.TreeView).set_cursor_on_cell (paths_list.nth_data (0), column, cells.nth_data (0), false);
                                    }
                                }
                            }
                        }
                    }
                    return false;
                });
            }
        }
    }
}
