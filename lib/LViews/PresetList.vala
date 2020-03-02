namespace Music2 {
    public class LViews.PresetList : Gtk.ComboBox {
        public signal void preset_selected (CObjects.EqualizerPreset p);
        public signal void automatic_preset_chosen ();
        public signal void delete_preset_chosen ();

        public CObjects.EqualizerPreset last_selected_preset;

        private bool automatic_selected;
        public bool automatic_chosen {
            get {
                return automatic_selected;
            }
        }

        private int ncustompresets {get; set;}
        private bool modifying_list;
        private const string SEPARATOR_NAME = "<separator_item_unique_name>";
        private static string automatic_mode = _("Automatic");
        private static string delete_preset = _("Delete Current");

        private Gtk.ListStore store;

        public PresetList () {
            ncustompresets = 0;
            modifying_list = false;
            automatic_selected = false;

            store = new Gtk.ListStore (2, typeof (GLib.Object), typeof (string));

            set_model (store);
            set_id_column (1);

            set_row_separator_func ((model, iter) => {
                string content = "";
                model.get (iter, 1, out content);

                return content == SEPARATOR_NAME;
            });

            var cell = new Gtk.CellRendererText ();
            cell.ellipsize = Pango.EllipsizeMode.END;

            pack_start (cell, true);
            add_attribute (cell, "text", 1);

            changed.connect (list_selection_change);

            show_all ();

            store.clear ();

            Gtk.TreeIter iter;
            store.append (out iter);
            store.set (iter, 0, null, 1, automatic_mode);

            add_separator ();
        }

        public void add_separator () {
            Gtk.TreeIter iter;
            store.append (out iter);
            store.set (iter, 0, null, 1, SEPARATOR_NAME);
        }

        public void add_preset (CObjects.EqualizerPreset ep) {
            modifying_list = true;

            if (!ep.is_default) {
                if (ncustompresets < 1) {
                    add_separator ();
                }

                ncustompresets++;
            }

            Gtk.TreeIter iter;
            store.append (out iter);
            store.set (iter, 0, ep, 1, ep.name);

            modifying_list = false;
            automatic_selected = false;

            set_active_iter (iter);
        }

        public void remove_current_preset () {
            modifying_list = true;

            Gtk.TreeIter iter;
            for (int i = 0; store.get_iter_from_string (out iter, i.to_string ()); ++i) {
                GLib.Object o;
                store.get (iter, 0, out o);

                if (o != null && o is CObjects.EqualizerPreset && ((CObjects.EqualizerPreset) o) == last_selected_preset) {
                    if (!((CObjects.EqualizerPreset) o).is_default) {
                        ncustompresets--;
                        store.remove (ref iter);
                        break;
                    }
                }
            }

            if (ncustompresets < 1) {
                remove_separator_item (-1);
            }

            modifying_list = false;

            select_automatic_preset ();
        }

        public virtual void list_selection_change () {
            if (modifying_list) {
                return;
            }

            Gtk.TreeIter it;
            get_active_iter (out it);

            GLib.Object o;
            store.get (it, 0, out o);

            if (o != null && o is CObjects.EqualizerPreset) {
                last_selected_preset = o as CObjects.EqualizerPreset;

                if (!(o as CObjects.EqualizerPreset).is_default) {
                    add_delete_preset_option ();
                } else {
                    remove_delete_option ();
                }

                automatic_selected = false;
                preset_selected (o as CObjects.EqualizerPreset);
                return;
            }

            string option;
            store.get (it, 1, out option);

            if (option == automatic_mode) {
                automatic_selected = true;
                remove_delete_option ();
                automatic_preset_chosen ();
            } else if (option == delete_preset) {
                delete_preset_chosen ();
            }
        }

        public void select_automatic_preset () {
            automatic_selected = true;
            automatic_preset_chosen ();
            set_active (0);
        }

        public void select_preset (string? preset_name) {
            if (!(preset_name == null || preset_name.length < 1)) {
                Gtk.TreeIter iter;
                for (int i = 0; store.get_iter_from_string (out iter, i.to_string ()); ++i) {
                    GLib.Object o;
                    store.get (iter, 0, out o);

                    if (o != null && o is CObjects.EqualizerPreset && (o as CObjects.EqualizerPreset).name == preset_name) {
                        set_active_iter (iter);
                        automatic_selected = false;
                        preset_selected (o as CObjects.EqualizerPreset);
                        return;
                    }
                }
            }

            select_automatic_preset ();
        }

        public CObjects.EqualizerPreset? get_selected_preset () {
            Gtk.TreeIter it;
            get_active_iter (out it);

            GLib.Object o;
            store.get (it, 0, out o);

            if (o != null && o is CObjects.EqualizerPreset) {
                return o as CObjects.EqualizerPreset;
            } else {
                return null;
            }
        }

        public CObjects.EqualizerPreset[] get_presets () {
            CObjects.EqualizerPreset[] rv = {};

            Gtk.TreeIter iter;
            for (int i = 0; store.get_iter_from_string (out iter, i.to_string ()); ++i) {
                GLib.Object o;
                store.get (iter, 0, out o);

                if (o != null && o is CObjects.EqualizerPreset) {
                    rv += (o as CObjects.EqualizerPreset);
                }
            }

            return rv;
        }

        private void remove_delete_option () {
            Gtk.TreeIter iter;
            for (int i = 0; store.get_iter_from_string (out iter, i.to_string ()); ++i) {
                string text;
                store.get (iter, 1, out text);

                if (text != null && text == delete_preset) {
                    store.remove (ref iter);
                    remove_separator_item (1);
                }
            }
        }

        private void remove_separator_item (int index) {
            int count = 0, nitems = store.iter_n_children (null);
            Gtk.TreeIter iter;

            for (int i = nitems - 1; store.get_iter_from_string (out iter, i.to_string ()); --i) {
                count++;
                string text;
                store.get (iter, 1, out text);

                if ((nitems - index == count || index == -1) && text != null && text == SEPARATOR_NAME) {
                    store.remove (ref iter);
                    break;
                }
            }
        }

        private void add_delete_preset_option () {
            bool already_added = false;
            Gtk.TreeIter last_iter, new_iter;

            for (int i = 0; store.get_iter_from_string (out last_iter, i.to_string ()); ++i) {
                string text;
                store.get (last_iter, 1, out text);

                if (text != null && text == SEPARATOR_NAME) {
                    new_iter = last_iter;

                    if (store.iter_next (ref new_iter)) {
                        store.get (new_iter, 1, out text);
                        already_added = (text == delete_preset);
                    }

                    break;
                }
            }

            if (already_added) {
                return;
            }

            store.insert_after (out new_iter, last_iter);
            store.set (new_iter, 0, null, 1, delete_preset);

            last_iter = new_iter;

            store.insert_after (out new_iter, last_iter);
            store.set (new_iter, 0, null, 1, SEPARATOR_NAME);
        }
    }
}
