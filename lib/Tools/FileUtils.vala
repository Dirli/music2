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

namespace Music2.Tools.FileUtils {
    public GLib.File get_cache_directory (string child_dir = "") {
        string data_dir = GLib.Environment.get_user_cache_dir ();
        string dir_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S, data_dir, Constants.APP_NAME, child_dir);

        var cache_dir = GLib.File.new_for_path (dir_path);

        if (!GLib.FileUtils.test (dir_path, GLib.FileTest.IS_DIR)) {
            try {
                cache_dir.make_directory_with_parents (null);
            } catch (Error e) {
                warning (e.message);
            }
        }

        return cache_dir;
    }

    public string get_cover_path (uint year, string album_name) {
        string cov_name = year.to_string () + album_name;
        string cov_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                                GLib.Environment.get_user_cache_dir (),
                                                Constants.APP_NAME,
                                                "covers",
                                                cov_name.hash ().to_string ());

        return GLib.FileUtils.test (cov_path, GLib.FileTest.EXISTS) ? cov_path : "";
    }

    public bool save_cover_file (GLib.File file, uint year, string album_name) {
        string cov_name = year.to_string () + album_name;

        var dest = get_cache_directory ("covers").get_child (cov_name.hash ().to_string ());

        try {
            file.copy (dest, GLib.FileCopyFlags.OVERWRITE);
            return true;
        } catch (Error e) {
            warning (e.message);
        }

        return false;
    }

    public bool is_audio_file (string mime_type) {
        return mime_type.has_prefix ("audio/") && !mime_type.contains ("x-mpegurl") && !mime_type.contains ("x-scpls");
    }
}
