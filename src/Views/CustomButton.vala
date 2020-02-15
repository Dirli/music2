namespace Music2 {
    public class Views.CustomButton : Gtk.Button {
        public CustomButton (string icon_name, string btn_title) {
            Gtk.Image button_image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.DIALOG);
            button_image.use_fallback = true;
            button_image.set_pixel_size (16);
            button_image.halign = Gtk.Align.CENTER;
            button_image.valign = Gtk.Align.CENTER;

            Gtk.Label button_title = new Gtk.Label (btn_title);
            button_title.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
            button_title.halign = Gtk.Align.START;
            button_title.valign = Gtk.Align.CENTER;

            Gtk.Grid button_grid = new Gtk.Grid ();
            button_grid.column_spacing = 10;

            button_grid.attach (button_image, 0, 0);
            button_grid.attach (button_title, 1, 0);

            add (button_grid);
        }
    }
}
