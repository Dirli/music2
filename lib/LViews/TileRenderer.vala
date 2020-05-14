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
    public class LViews.TileRenderer : Gtk.CellRenderer {
        public Structs.Album? album { get; set; }

        private Gee.HashMap<int, Gdk.Pixbuf> covers_hash;

        private Pango.Layout title_text_layout;
        private Gtk.Border margin;
        private Gtk.Border padding;
        private Gtk.Border border;
        private Gdk.Pixbuf pixbuf;

        public TileRenderer () {
            covers_hash = new Gee.HashMap<int, Gdk.Pixbuf> ();
            notify["album"].connect (() => {
                pixbuf = null;
            });
        }

        public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area, out int x_offset, out int y_offset, out int width, out int height) {
            x_offset = y_offset = width = height = 0;
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void get_preferred_width (Gtk.Widget widget, out int minimum_size, out int natural_size) {
            update_layout_properties (widget);

            int x_padding;
            get_padding (out x_padding, null);

            int width = compute_total_image_width ()
                      + margin.left + margin.right
                      + padding.left + padding.right
                      + border.left + border.right
                      + 2 * x_padding;

            minimum_size = natural_size = width;
        }

        public override void get_preferred_height_for_width (Gtk.Widget widget, int width, out int minimum_height, out int natural_height) {
            update_layout_properties (widget);

            int y_padding;
            get_padding (null, out y_padding);

            int title_height;
            title_text_layout.get_pixel_size (null, out title_height);

            int height = compute_total_image_height ()
                       + title_height
                       + margin.top + 2 * margin.bottom
                       + padding.top + padding.bottom
                       + border.top + border.bottom
                       + 2 * y_padding;

            minimum_height = natural_height = height;
        }

        public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle bg_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
            update_layout_properties (widget);

            Gdk.Rectangle aligned_area = get_aligned_area (widget, flags, cell_area);

            int x = aligned_area.x;
            int y = aligned_area.y;
            int width = aligned_area.width;
            int height = aligned_area.height;

            // Apply margin, border width and padding offsets
            x += margin.left + border.left + padding.left;
            y += margin.top + border.top + padding.top;

            weak Gtk.StyleContext ctx = widget.get_style_context ();

            width -= margin.left + margin.right + border.left + border.right + padding.left + padding.right;
            height -= margin.top + margin.bottom + border.top + border.bottom + padding.top + padding.bottom;

            render_image (ctx, cr, ref x, ref y, width, flags);
            render_title (ctx, cr, x, ref y, width);
        }

        private void render_image (Gtk.StyleContext ctx, Cairo.Context cr, ref int x, ref int y, int width, Gtk.CellRendererState flags) {
            int image_width = compute_total_image_width ();
            int image_height = compute_total_image_height ();

            x += (width - image_width) / 2;

            ctx.save ();
            ctx.add_class ("album");
            ctx.add_class (Granite.STYLE_CLASS_CARD);
            ctx.render_background (cr, x, y, 128, 128);

            if (pixbuf != null) {
                int scale_factor = ctx.get_scale ();

                var surface = Gdk.cairo_surface_create_from_pixbuf (pixbuf, scale_factor, null);

                ctx.render_icon_surface (cr, surface, x, y);
            }

            cr.fill_preserve ();
            ctx.render_frame (cr, x - border.left, y - border.top, 128 + border.left + border.right, 128 + border.top + border.bottom);
            ctx.restore ();

            y += image_height;

            // move x to the start of the actual image
            x += (image_width - 128) / 2 - margin.left;
        }

        private void render_title (Gtk.StyleContext ctx, Cairo.Context cr, int x, ref int y, int width) {
            ctx.save ();
            ctx.add_class ("h4");
            ctx.render_layout (cr, x, y, title_text_layout);
            ctx.restore ();

            int title_height;
            title_text_layout.get_pixel_size (null, out title_height);

            y += title_height;
        }

        private void update_layout_properties (Gtk.Widget widget) {
            if (album == null) {
                return;
            }

            var ctx = widget.get_style_context ();
            var state = ctx.get_state ();
            var scale = ctx.get_scale ();

            if (pixbuf == null) {
                if (covers_hash.has_key (album.album_id)) {
                    pixbuf = covers_hash[album.album_id];
                } else {
                    pixbuf = Tools.GuiUtils.get_cover_pixbuf (album.year, album.title, scale);
                    if (pixbuf != null) {
                        covers_hash[album.album_id] = pixbuf;
                    }
                }
            }

            border.left = 12;
            border.right = 12;
            border.bottom = 12;
            border.top = 12;

            ctx.save ();
            ctx.add_class ("album");
            margin = border;
            padding = ctx.get_padding (state);
            border = ctx.get_border (state);
            ctx.restore ();

            unowned Pango.FontDescription font_description;
            ctx.get (state, Gtk.STYLE_PROPERTY_FONT, out font_description);
            int text_width = 128 * Pango.SCALE;

            ctx.save ();
            ctx.add_class ("h4");
            title_text_layout = widget.create_pango_layout (album.title);
            ctx.get (state, Gtk.STYLE_PROPERTY_FONT, out font_description);
            title_text_layout.set_font_description (font_description);
            title_text_layout.set_width (text_width);
            title_text_layout.set_ellipsize (Pango.EllipsizeMode.END);
            title_text_layout.set_alignment (Pango.Alignment.LEFT);
            ctx.restore ();
        }

        private int compute_total_image_width () {
            return 128 + margin.left + margin.right;
        }

        private int compute_total_image_height () {
            return 128 + margin.top + margin.bottom;
        }
    }
}
