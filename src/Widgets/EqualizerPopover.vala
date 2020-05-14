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
    public class Widgets.EqualizerPopover : Gtk.Popover {
        public signal void preset_changed (string preset_name);

        private Gtk.Switch eq_switch;
        private Gtk.Entry new_preset_entry;
        private Gtk.Grid side_list;
        private Gtk.Grid scale_container;
        private LViews.PresetList preset_combo;

        private GLib.Settings eq_settings;

        private Gee.ArrayList<Gtk.Scale> scales;
        private Gee.ArrayList<int> target_levels;

        private string new_preset_name;
        private bool apply_changes = false;
        private bool initialized = false;
        private bool closing = false;
        private bool adding_preset = false;
        private bool in_transition = false;

        construct {
            eq_settings = new GLib.Settings (Constants.APP_NAME + ".equalizer");

            scales = new Gee.ArrayList<Gtk.Scale> ();
            target_levels = new Gee.ArrayList<int> ();
        }

        public void init () {
            assert (!initialized);

            build_ui ();
            load_presets ();
            initialized = true;

            if (eq_settings.get_boolean ("auto-switch-preset")) {
                preset_combo.select_automatic_preset ();
            } else {
                var preset = eq_settings.get_string ("selected-preset");
                preset_combo.select_preset (preset);
            }

            on_eq_switch_toggled ();
            apply_changes = true;
        }

        public override void closed () {
            closing = true;

            if (in_transition) {
                set_target_levels ();
            } else if (adding_preset) {
                add_new_preset ();
            }

            save_presets ();

            var selected_preset = preset_combo.get_selected_preset ();
            eq_settings.set_string ("selected-preset", selected_preset != null ? selected_preset.name : "");
            eq_settings.set_boolean ("auto-switch-preset", preset_combo.automatic_chosen);

            closing = false;
        }

        public bool verify_preset_name (string preset_name) {
            if (preset_name == null || Tools.String.is_white_space (preset_name)) {
                return false;
            }

            foreach (unowned CObjects.EqualizerPreset preset in preset_combo.get_presets ()) {
                if (preset_name == preset.name) {
                    return false;
                }
            }

            return true;
        }

        private void build_ui () {
            height_request = 240;

            scale_container = new Gtk.Grid ();
            scale_container.column_spacing = 12;
            scale_container.margin = 18;
            scale_container.margin_bottom = 0;

            foreach (string decibel in Constants.DECIBELS) {
                var scale = new Gtk.Scale.with_range (Gtk.Orientation.VERTICAL, -80, 80, 1);
                scale.add_mark (0, Gtk.PositionType.LEFT, null);
                scale.draw_value = false;
                scale.inverted = true;
                scale.vexpand = true;

                var label = new Gtk.Label (decibel);

                var holder = new Gtk.Grid ();
                holder.orientation = Gtk.Orientation.VERTICAL;
                holder.row_spacing = 6;
                holder.add (scale);
                holder.add (label);

                scale_container.add (holder);
                scales.add (scale);

                scale.value_changed.connect (() => {
                    if (initialized && apply_changes && !preset_combo.automatic_chosen) {
                        int index = scales.index_of (scale);
                        int val = (int) scale.get_value ();
                        // App.player.player.set_equalizer_gain (index, val);

                        if (!in_transition) {
                            var selected_preset = preset_combo.get_selected_preset ();

                            if (selected_preset.is_default) {
                                on_default_preset_modified ();
                            } else {
                                selected_preset.set_gain (index, val);
                            }
                        }
                    }
                });
            }

            eq_switch = new Gtk.Switch ();
            eq_switch.valign = Gtk.Align.CENTER;

            preset_combo = new LViews.PresetList ();
            preset_combo.hexpand = true;

            side_list = new Gtk.Grid ();
            side_list.add (preset_combo);
            new_preset_entry = new Gtk.Entry ();
            new_preset_entry.hexpand = true;
            new_preset_entry.secondary_icon_name = "document-save-symbolic";
            new_preset_entry.secondary_icon_tooltip_text = _("Save preset");

            var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
            size_group.add_widget (preset_combo);
            size_group.add_widget (new_preset_entry);

            var bottom_controls = new Gtk.Grid ();
            bottom_controls.column_spacing = 12;
            bottom_controls.margin = 12;
            bottom_controls.margin_top = 0;
            bottom_controls.add (eq_switch);
            bottom_controls.add (side_list);

            var layout = new Gtk.Grid ();
            layout.orientation = Gtk.Orientation.VERTICAL;
            layout.row_spacing = 12;

            layout.add (scale_container);
            layout.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            layout.add (bottom_controls);
            layout.show_all ();

            add (layout);

            eq_settings.bind ("equalizer-enabled", eq_switch, "active", GLib.SettingsBindFlags.DEFAULT);
            eq_settings.bind ("equalizer-enabled", preset_combo, "sensitive", GLib.SettingsBindFlags.GET);
            eq_settings.bind ("equalizer-enabled", scale_container, "sensitive", GLib.SettingsBindFlags.GET);

            eq_switch.notify["active"].connect (on_eq_switch_toggled);
            preset_combo.automatic_preset_chosen.connect (on_automatic_chosen);
            preset_combo.delete_preset_chosen.connect (remove_preset_clicked);
            preset_combo.preset_selected.connect (on_preset_selected);
            new_preset_entry.activate.connect (add_new_preset);
            new_preset_entry.icon_press.connect (new_preset_entry_icon_pressed);
            new_preset_entry.focus_out_event.connect (on_entry_focus_out);
        }

        private bool on_entry_focus_out () {
            if (!closing) {
                new_preset_entry.grab_focus ();
            }

            return false;
        }

        private void on_eq_switch_toggled () {
            assert (initialized);

            in_transition = false;

            if (eq_settings.get_boolean ("equalizer-enabled")) {
                if (preset_combo.automatic_chosen) {
                    preset_combo.select_automatic_preset ();
                } else {
                    var selected_preset = preset_combo.get_selected_preset ();

                    if (selected_preset != null) {
                        for (int i = 0; i < scales.size; ++i) {
                            //
                        }
                    }
                }
            } else {
                for (int i = 0; i < scales.size; ++i) {
                    //
                }
            }

            notify_current_preset ();
        }

        private void load_presets () {
            foreach (unowned CObjects.EqualizerPreset preset in get_default_presets ()) {
                preset.is_default = true;
                preset_combo.add_preset (preset);
            }

            foreach (unowned CObjects.EqualizerPreset preset in get_presets ()) {
                preset_combo.add_preset (preset);
            }
        }

        private void save_presets () {
            var val = new string[0];
            foreach (unowned CObjects.EqualizerPreset preset in preset_combo.get_presets ()) {
                if (!preset.is_default) {
                    val += preset.to_string ();
                }
            }

            eq_settings.set_strv ("custom-presets", val);
        }

        private void set_target_levels () {
            in_transition = false;

            for (int index = 0; index < scales.size; ++index) {
                var scale = scales.get (index);
                scale.set_value (target_levels.get (index));
            }
        }

        private void on_preset_selected (CObjects.EqualizerPreset p) {
            if (!initialized) {
                return;
            }

            scale_container.sensitive = true;
            target_levels.clear ();

            foreach (int i in p.gains) {
                target_levels.add (i);
            }

            if (closing || (initialized && !apply_changes) || adding_preset) {
                set_target_levels ();
            } else if (!in_transition) {
                in_transition = true;
                GLib.Timeout.add (Constants.ANIMATION_TIMEOUT, transition_scales);
            }
        }

        private bool transition_scales () {
            if (!in_transition) {
                return false;
            }

            bool is_finished = true;

            for (int index = 0; index < scales.size; ++index) {
                var scale = scales.get (index);
                double current_level = scale.get_value ();
                double target_level = target_levels.get (index);
                double difference = target_level - current_level;

                if (closing || Math.fabs (difference) <= 1) {
                    scale.set_value (target_level);
                    notify_current_preset ();

                    if (!preset_combo.automatic_chosen && target_level == 0) {
                        //
                    }
                } else {
                    scale.set_value (scale.get_value () + (difference / 8.0));
                    is_finished = false;
                }
            }

            if (is_finished) {
                in_transition = false;
                return false;
            }

            return true;
        }

        private void notify_current_preset () {
            if (eq_settings.get_boolean ("equalizer-enabled")) {
                if (preset_combo.automatic_chosen) {
                    preset_changed (_("Automatic"));
                } else {
                    preset_changed (preset_combo.get_selected_preset ().name);
                }
            } else {
                preset_changed (_("Off"));
            }
        }

        private void on_automatic_chosen () {
            eq_settings.set_boolean ("auto-switch-preset", preset_combo.automatic_chosen);

            target_levels.clear ();

            for (int i = 0; i < scales.size; ++i) {
                target_levels.add (0);
            }

            scale_container.sensitive = false;

            if (apply_changes) {
                in_transition = true;
                GLib.Timeout.add (Constants.ANIMATION_TIMEOUT, transition_scales);
                save_presets ();
            } else {
                set_target_levels ();
            }
        }

        private void on_default_preset_modified () {
            if (adding_preset || closing) {
                return;
            }

            adding_preset = true;

            side_list.remove (preset_combo);
            side_list.add (new_preset_entry);
            side_list.show_all ();

            new_preset_name = create_new_preset_name (true);

            new_preset_entry.set_text (new_preset_name);
            eq_switch.sensitive = false;
            new_preset_entry.grab_focus ();
        }

        private void new_preset_entry_icon_pressed (Gtk.EntryIconPosition pos, Gdk.Event event) {
            if (pos != Gtk.EntryIconPosition.SECONDARY && !adding_preset) {
                return;
            }

            add_new_preset ();
        }

        private void add_new_preset () {
            if (!adding_preset) {
                return;
            }

            var new_name = new_preset_entry.get_text ();

            if (verify_preset_name (new_name)) {
                new_preset_name = new_name;
            }

            int[] gains = new int[scales.size];

            for (int i = 0; i < scales.size; i++) {
                gains[i] = (int) scales.get (i).get_value ();
            }

            var new_preset = new CObjects.EqualizerPreset.with_gains (new_preset_name, gains);
            preset_combo.add_preset (new_preset);

            side_list.add (preset_combo);
            side_list.set_focus_child (preset_combo);
            side_list.remove (new_preset_entry);
            side_list.show_all ();

            eq_switch.sensitive = true;
            adding_preset = false;
        }

        private string create_new_preset_name (bool from_current) {
            string current_preset_name = from_current ? preset_combo.get_selected_preset ().name : "";
            string preset_name = "";

            bool is_valid = false;
            int i = 0;

            do {
                if (from_current) {
                    if (i < 1) {
                        preset_name = _("%s (Custom)").printf (current_preset_name);
                    } else {
                        preset_name = _("%s (Custom %i)").printf (current_preset_name, i);
                    }
                } else {
                    if (i < 1) {
                        preset_name = _("Custom Preset");
                    } else {
                        preset_name = _("Custom Preset %i").printf (i);
                    }
                }

                i++;
                is_valid = verify_preset_name (preset_name);
            } while (!is_valid);

            return preset_name;
        }

        private void remove_preset_clicked () {
            preset_combo.remove_current_preset ();
        }

        private CObjects.EqualizerPreset[] get_presets () {
            string[] presets_data = {};
            string[] custom_presets = eq_settings.get_strv ("custom-presets");

            if (custom_presets != null) {
                for (int i = 0; i < custom_presets.length; i++) {
                    presets_data += custom_presets[i];
                }
            }

            CObjects.EqualizerPreset[] rv = {};

            foreach (var preset_str in presets_data) {
                rv += new CObjects.EqualizerPreset.from_string (preset_str);
            }

            return rv;
        }

        private CObjects.EqualizerPreset[] get_default_presets () {
            CObjects.EqualizerPreset[] default_presets = {};

            foreach (unowned Enums.PresetGains preset_gains in Enums.PresetGains.get_all ()) {
                default_presets += new CObjects.EqualizerPreset.with_gains (preset_gains.to_string (), preset_gains.get_gains ());
            }

            return default_presets;
        }
    }
}
