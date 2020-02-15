namespace Music2 {
    public class Views.DnDSelection : Gtk.Box {
        public signal void button_clicked (Enums.ActionType action_type);

        public DnDSelection () {
            orientation = Gtk.Orientation.VERTICAL;
            spacing = 8;
            margin_top = margin_bottom = 8;
            margin_start = margin_end = 10;

            var play_btn = new Views.CustomButton ("media-playback-start-symbolic", "Play");
            play_btn.clicked.connect (() => {
                button_clicked (Enums.ActionType.PLAY);
            });

            var load_btn = new Views.CustomButton ("go-down-symbolic", "Load");
            load_btn.clicked.connect (() => {
                button_clicked (Enums.ActionType.LOAD);
            });

            var cancel_btn = new Views.CustomButton ("pane-hide-symbolic", "Cancel");
            cancel_btn.clicked.connect (() => {
                button_clicked (Enums.ActionType.NONE);
            });

            add (play_btn);
            add (load_btn);
            add (cancel_btn);

            show_all ();
        }
    }
}
