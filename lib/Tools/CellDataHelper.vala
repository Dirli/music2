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
        if (model == null) {
            return;
        }

        var image_renderer = renderer as Gtk.CellRendererPixbuf;

        if (image_renderer != null || renderer.visible) {
            Value icon;
            model.get_value (iter, (int) Enums.ListColumn.ICON, out icon);
            image_renderer.gicon = icon.get_object () as GLib.Icon;
        }
    }

    public static inline void number_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        if (tree_model == null) {
            return;
        }

        var renderer_text = cell as Gtk.CellRendererText;
        if (renderer_text != null) {
            set_renderer_number (renderer_text, iter, tree_model, Enums.ListColumn.TRACK);
        }
    }

    public static inline void intelligent_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        if (tree_model == null) {
            return;
        }

        var tvc = layout as Gtk.TreeViewColumn;

        if (tvc != null) {
            int column = tvc.sort_column_id;
            if (column < 0) {
                return;
            }

            var renderer_text = cell as Gtk.CellRendererText;
            if (renderer_text != null) {
                set_renderer_number (renderer_text, iter, tree_model, column);
            }
        }
    }

    private static inline void set_renderer_number (Gtk.CellRendererText renderer, Gtk.TreeIter iter, Gtk.TreeModel model, int column) {
        uint val;
        model.@get (iter, column, out val, -1);

        renderer.text = val > 0 ? val.to_string () : "";
    }

    // public static inline void string_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
    //     if (tree_model == null) {
    //         return;
    //     }
    //
    //     var tvc = layout as Gtk.TreeViewColumn;
    //
    //     if (tvc != null) {
    //         int column = tvc.sort_column_id;
    //         if (column < 0) {
    //             return;
    //         }
    //
    //         string val;
    //         tree_model.@get (iter, column, out val, -1);
    //         var renderer_text = cell as Gtk.CellRendererText;
    //         if (renderer_text != null) {
    //             renderer_text.text = val;
    //         }
    //     }
    // }

    public static inline void length_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        if (tree_model == null) {
            return;
        }

        uint ms;
        tree_model.@get (iter, (int) Enums.ListColumn.LENGTH, out ms, -1);
        var renderer_text = cell as Gtk.CellRendererText;
        if (renderer_text != null) {
            renderer_text.text = (ms <= 0) ? Constants.NOT_AVAILABLE : Granite.DateTime.seconds_to_time ((int) (ms / Constants.MILI_INV));
        }
    }

    public static inline void bitrate_func (Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        if (tree_model == null) {
            return;
        }

        uint val;
        tree_model.@get (iter, (int) Enums.ListColumn.BITRATE, out val, -1);
        var renderer_text = cell as Gtk.CellRendererText;
        if (renderer_text != null) {
            renderer_text.text = val <= 0 ? Constants.NOT_AVAILABLE : _("%u kbps").printf (val);
        }
    }

    public static inline string get_date_string (uint n) {
        return n == 0 ? _("Never") : Tools.TimeUtils.pretty_timestamp_from_time (Time.local (n));
    }
}
