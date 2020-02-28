namespace Music2 {
    public class Views.ViewSelector : Gtk.ToolItem {
        public Granite.Widgets.ModeButton mode_button;

        public ViewSelector () {
            var image = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.MENU);
            var column = new Gtk.Image.from_icon_name ("view-column-symbolic", Gtk.IconSize.MENU);

            mode_button = new Granite.Widgets.ModeButton ();
            mode_button.append (image);
            mode_button.append (column);

            add (mode_button);
        }
    }
}
