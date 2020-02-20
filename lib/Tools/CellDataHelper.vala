namespace Music2.Tools.CellDataHelper {
    public static Enums.ListColumn? get_column_type (Gtk.TreeViewColumn column) {
        int type = column.get_data<int> (Constants.TYPE_DATA_KEY);

        if (type < 0) {
            critical ("get_column_type: Column '%s' has no associated type.", column.title);
            GLib.return_val_if_reached (null);
        }

        return (Enums.ListColumn) type;
    }

    public static void icon_func (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {
        var image_renderer = renderer as Gtk.CellRendererPixbuf;
        GLib.return_if_fail (image_renderer != null);

        if (renderer.visible) {
            Value icon;
            model.get_value (iter, Enums.ListColumn.ICON, out icon);
            image_renderer.gicon = icon.get_object () as GLib.Icon;
        }
    }

    public static inline void number_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        set_renderer_number (cell as Gtk.CellRendererText, iter, tree_model, Enums.ListColumn.TRACK);
    }

    public static inline void intelligent_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        var tvc = layout as Gtk.TreeViewColumn;
        GLib.return_if_fail (tvc != null);

        int column = tvc.sort_column_id;
        if (column < 0) {
            return;
        }

        set_renderer_number (cell as Gtk.CellRendererText, iter, tree_model, column);
    }

    private static inline void set_renderer_number (Gtk.CellRendererText renderer, Gtk.TreeIter iter, Gtk.TreeModel model, int column) {
        if ((model as Gtk.ListStore).iter_is_valid (iter)) {
            GLib.Value? val;
            model.get_value (iter, column, out val);

            if (val != null) {
                uint n = val.get_uint ();
                renderer.text = n > 0 ? n.to_string () : "";
            }
        }
    }

    public static inline void string_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        if ((tree_model as Gtk.ListStore).iter_is_valid (iter)) {
            var tvc = layout as Gtk.TreeViewColumn;
            GLib.return_if_fail (tvc != null);

            int column = tvc.sort_column_id;
            if (column < 0) {
                return;
            }

            GLib.Value? val;
            tree_model.get_value (iter, column, out val);
            if (val != null) {
                (cell as Gtk.CellRendererText).text = val.get_string ();
            }
        }
    }

    public static inline void length_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        if ((tree_model as Gtk.ListStore).iter_is_valid (iter)) {
            GLib.Value? val;
            tree_model.get_value (iter, Enums.ListColumn.LENGTH, out val);
            if (val != null) {
                uint ms = val.get_uint ();
                (cell as Gtk.CellRendererText).text = (ms <= 0) ? Constants.NOT_AVAILABLE : Granite.DateTime.seconds_to_time ((int) (ms / Constants.MILI_INV));
            }
        }
    }

    public static inline void bitrate_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        if ((tree_model as Gtk.ListStore).iter_is_valid (iter)) {
            GLib.Value? val;
            tree_model.get_value (iter, Enums.ListColumn.BITRATE, out val);
            if (val != null) {
                uint n = val.get_uint ();
                (cell as Gtk.CellRendererText).text = n <= 0 ? Constants.NOT_AVAILABLE : _("%u kbps").printf (n);
            }
        }
    }

    public static inline string get_date_string (uint n) {
        return n == 0 ? _("Never") : Tools.TimeUtils.pretty_timestamp_from_time (Time.local (n));
    }
}
