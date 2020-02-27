namespace Music2 {
    public class Views.ProgressBox : Gtk.Box {
        public signal void cancelled_scan ();

        private Gtk.Label progress_label;
        private Gtk.ProgressBar progress_bar;

        public ProgressBox () {
            orientation = Gtk.Orientation.HORIZONTAL;
            spacing = 5;
            margin_top = margin_bottom = 5;
            margin_start = margin_end = 8;

            progress_label = new Gtk.Label ("0%");
            progress_bar = new Gtk.ProgressBar ();
            progress_bar.fraction = 0;
            progress_bar.valign = Gtk.Align.CENTER;

            var cancel_button = new Gtk.Button.from_icon_name ("process-stop-symbolic", Gtk.IconSize.MENU);
            cancel_button.halign = cancel_button.valign = Gtk.Align.CENTER;
            cancel_button.tooltip_text = _("Cancel");
            cancel_button.clicked.connect (() => {
                cancelled_scan ();
            });

            add (progress_label);
            add (progress_bar);
            add (cancel_button);

            show_all ();
        }

        public void update_progress (double progress) {
            if (progress <= 1) {
                progress_label.set_text ("%d%%".printf ((int) (progress * 100)));
                progress_bar.fraction = progress;
            }
        }
    }
}
