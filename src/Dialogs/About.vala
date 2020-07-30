namespace Music2 {
    public class Dialogs.About : Gtk.Dialog {
        public About () {
            Object (modal: true,
                    deletable: false,
                    resizable: false,
                    destroy_with_parent: true);

            set_default_response (Gtk.ResponseType.CANCEL);

            var logo_image = new Gtk.Image ();
            logo_image.pixel_size = 128;
            logo_image.icon_name = "multimedia-audio-player";

            var name_label = new AboutLabel ("Pantheon-music2 " + Constants.VERSION);
            name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

            var comments_label = new AboutLabel (_("Simple music player designed for Pantheon DE\n"));

            var license_url = "http://www.gnu.org/licenses/lgpl.html";
            var license_label = new AboutLabel ("");
            license_label.set_markup (
                "<span size=\"small\">" + _("This program is published under the terms of the %s license, it comes with ABSOLUTELY NO WARRANTY; for details, visit %s").printf (
                    "GPL",
                    "<a href=\"" + license_url + "\">" + license_url + "</a></span>\n"
                )
            );

            string[] authors = {
                "Dirli <litandrej85@gmail.com>"
            };

            var authors_label = new AboutLabel ("");
            authors_label.set_markup (
                set_string_from_string_array ("<span size=\"small\">" + _("Written by:") + "</span>\n", authors)
            );

            var content_scrolled_grid = new Gtk.Grid ();
            content_scrolled_grid.orientation = Gtk.Orientation.VERTICAL;
            content_scrolled_grid.add (comments_label);
            content_scrolled_grid.add (license_label);
            content_scrolled_grid.add (authors_label);

            var content_scrolled = new Gtk.ScrolledWindow (null, null);
            content_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
            content_scrolled.vexpand = true;
            content_scrolled.width_request = 330;
            content_scrolled.add (content_scrolled_grid);

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 12;
            grid.height_request = 136;
            grid.margin = 12;
            grid.attach (logo_image,       0, 0, 1, 2);
            grid.attach (name_label,       1, 0);
            grid.attach (content_scrolled, 1, 1);

            var content_area = (Gtk.Box) get_content_area ();
            content_area.border_width = 5;
            content_area.add (grid);

            var close_button = add_button (_("Close"), Gtk.ResponseType.CANCEL);
            close_button.grab_focus ();

            response.connect (() => {destroy ();});
            show_all ();
        }

        private class AboutLabel : Gtk.Label {
            public AboutLabel (string label) {
                Object (
                    label: label,
                    max_width_chars: 48,
                    selectable: true,
                    wrap: true,
                    xalign: 0
                );
            }
        }

        private string set_string_from_string_array (string title, string[] peoples, bool tooltip = false) {
            if (tooltip) {
                return string.joinv ("\n", peoples);
            }

            string text = "";
            string name = "";
            string email = "" ;
            string _person_data;
            bool email_started = false;
            text += title + "<span size=\"small\">";

            for (int i= 0; i < peoples.length; i++) {
                if (peoples[i] == null) {
                    break;
                }

                _person_data = peoples[i];

                for (int j=0; j < _person_data.length; j++) {
                    if ( _person_data.get (j) == '<') {
                        email_started = true;
                    }

                    if (!email_started) {
                        name += _person_data[j].to_string ();
                    } else {
                        if (_person_data.get (j) != '>' && _person_data.get (j) != '<') {
                            email += _person_data[j].to_string ();
                        }
                    }
                }

                if (email == "") {
                    text += "<u>%s</u>\n".printf (name.strip ());
                } else {
                    text += "<a href=\"mailto:%s\" title=\"%s\">%s</a>\n".printf (
                        email,
                        email,
                        name.strip ()
                    );
                }

                email = ""; name = ""; email_started = false;
            }
            text += "</span>";
            return text;
        }
    }
}
