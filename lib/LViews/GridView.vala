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
    public class LViews.GridView : Gtk.IconView {
        private Gtk.CellRenderer cell_renderer;

        public GridView () {
            cell_renderer = new LViews.TileRenderer ();
            pack_start (cell_renderer, false);

            activate_on_single_click = false;
            add_attribute (cell_renderer, "album", 0);

            tooltip_column = 1;
            item_padding = 0;
            margin = 24;
        }

        public override void size_allocate (Gtk.Allocation alloc) {
            Gtk.Requisition minimum_size, natural_size;
            cell_renderer.get_preferred_size (this, out minimum_size, out natural_size);
            int item_width = minimum_size.width;

            if (item_width <= 0) {
                base.size_allocate (alloc);
            }

            int total_width = alloc.width;
            double num = total_width - 2 * margin;
            double denom = item_width;
            columns = (int) (num / denom);
            num = total_width - columns * item_width - 2 * margin;
            denom = columns - 1;
            column_spacing = (int) (num / denom);
            base.size_allocate (alloc);
        }
    }
}
