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

    public bool is_audio_file (string mime_type) {
        return mime_type.has_prefix ("audio/") && !mime_type.contains ("x-mpegurl") && !mime_type.contains ("x-scpls");
    }
}
