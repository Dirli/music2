namespace Music2 {
    public class CObjects.EqualizerPreset : GLib.Object {
        public string name { get; construct set; }
        public int[] gains;

        public bool is_default { get; set; default = false; }

        public EqualizerPreset.basic (string name) {
            Object (name: name);

            int[] tmp_gains = {};
            for (int i = 0; i < 10; i++) {
                tmp_gains += 0;
            }

            gains = tmp_gains;
        }

        public EqualizerPreset.with_gains (string name, int[] items) {
            Object (name: name);

            int[] tmp_gains = {};
            for (int i = 0; i < 10; i++) {
                tmp_gains += items[i];
            }

            gains = tmp_gains;
        }

        public EqualizerPreset.from_string (string data) {
            var vals = data.split ("/", 0);
            Object (name: vals[0]);

            int[] tmp_gains = {};
            for (int i = 1; i < vals.length; i++) {
                tmp_gains += int.parse (vals[i]);
            }

            gains = tmp_gains;
        }

        public string to_string () {
            string str_preset = "";

            if (name != null && name != "") {
                str_preset = name;
                for (int i = 0; i < 10; i++) {
                    str_preset += "/" + get_gain (i).to_string ();
                }
            }

            return str_preset;
        }

        public void set_gain (int index, int val) {
            if (index > 9) {
                return;
            }

            gains[index] = val;
        }

        public int get_gain (int index) {
            return gains[index];
        }
    }
}
