namespace Music2 {
    public class Views.ProgressBox : Gtk.Box {
        public signal void cancelled_scan ();

        private Gtk.Label count_label;
        private Gtk.Label progress_label;
        private Gtk.ProgressBar progress_bar;

        public ProgressBox () {
            Object (margin_bottom: 5,
                    margin_end: 8,
                    margin_start: 8,
                    margin_top: 5,
                    orientation: Gtk.Orientation.VERTICAL,
                    spacing: 5);
        }

        construct {
            count_label = new Gtk.Label ("0") {
                halign = Gtk.Align.CENTER
            };
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

            var h_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
            h_box.add (progress_label);
            h_box.add (progress_bar);
            h_box.add (cancel_button);

            add (count_label);
            add (h_box);

            show_all ();
        }

        public void update_progress (double progress, string count) {
            count_label.set_text (count);

            if (progress <= 1) {
                progress_label.set_text ("%d%%".printf ((int) (progress * 100)));
                progress_bar.fraction = progress;
            }
        }
    }
}
