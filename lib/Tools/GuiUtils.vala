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

namespace Music2.Tools.GuiUtils {
    public Structs.Album get_album_struct (CObjects.Media m, int album_id, int artist_id) {
        Structs.Album album_struct = {};

        album_struct.album_id = album_id;
        album_struct.title = m.album;
        album_struct.year = m.year;

        return album_struct;
    }

    public CObjects.Media? metadata_to_media (GLib.HashTable<string, GLib.Variant> metadata) {
        if ("xesam:url" in metadata) {
            CObjects.Media m = new CObjects.Media (metadata["xesam:url"].get_string ());

            m.tid = (uint) metadata["mpris:trackid"].get_int64 ();
            m.length = (uint) metadata["mpris:length"].get_int64 ();
            m.title = metadata["xesam:title"].get_string ();
            m.album = metadata["xesam:album"].get_string ();
            var artists = metadata["xesam:artist"].get_strv ();
            m.artist = artists[0];
            var genre = metadata["xesam:genre"].get_strv ();
            m.genre = genre[0];
            m.track = (uint) metadata["xesam:trackNumber"].get_int32 ();
            m.year = metadata["music2:year"].get_uint16 (); // missing from the specification

            return m;
        }

        return null;
    }

    public GLib.Icon? get_cover_icon (uint a_year, string a_title) {
        string cov_path = Tools.FileUtils.get_cover_path (a_year, a_title);
        if (cov_path != "") {
            var cover_file = GLib.File.new_for_path (cov_path);
            if (cover_file.query_exists ()) {
                return new GLib.FileIcon (cover_file);
            }
        }

        return null;
    }

    public Gdk.Pixbuf? get_cover_pixbuf (uint a_year, string? a_title, int scale) {
        if (a_title != null) {
            var cover_icon = get_cover_icon (a_year, a_title);

            if (cover_icon != null) {
                var icon_info = Gtk.IconTheme.get_default ().lookup_by_gicon_for_scale (cover_icon, 128, scale, 0);
                Gdk.Pixbuf? cover_pixbuf = null;

                try {
                    cover_pixbuf = icon_info.load_icon ();
                } catch (Error e) {
                    warning (e.message);
                    return null;
                }

                return cover_pixbuf;
            }
        }

        return null;
    }

    public Gtk.Label get_settings_label (string text) {
        var settings_label = new Gtk.Label (text);
        settings_label.halign = Gtk.Align.END;
        settings_label.hexpand = true;
        settings_label.margin_start = 12;

        return settings_label;
    }

    public string get_playlist_path (string playlist_name, string library_path) {
        if (playlist_name == "") {
            return "";
        }

        var m3u_filter = new Gtk.FileFilter ();
        m3u_filter.add_pattern ("*.m3u");
        m3u_filter.set_filter_name (_("MPEG Version 3.0 Extended (*.m3u)"));

        var file_chooser = new Gtk.FileChooserNative (_("Export Playlist"),
                                                      null,
                                                      Gtk.FileChooserAction.SAVE,
                                                      _("Save"),
                                                      _("Cancel"));

        file_chooser.do_overwrite_confirmation = true;
        file_chooser.set_current_name (playlist_name + ".m3u");
        file_chooser.add_filter (m3u_filter);

        if (library_path != "" && GLib.File.new_for_path (library_path).query_exists ()) {
            file_chooser.set_current_folder (library_path);
        } else {
            file_chooser.set_current_folder (GLib.Environment.get_home_dir ());
        }

        string file = "";

        if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
            file = file_chooser.get_filename ();
            string extension = file.slice (file.last_index_of ("."), -1);

            if (extension.length == 0 || extension[0] != '.') {
                extension = ".m3u";
                file += extension;
            }
        }

        file_chooser.destroy ();

        return file;
    }
}
