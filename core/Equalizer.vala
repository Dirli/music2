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
    public class Core.Equalizer : GLib.Object {
        public dynamic Gst.Element element;

        construct {
            element = Gst.ElementFactory.make ("equalizer-10bands", "equalizer");

            int[10] freqs = {60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000};
            float last_freq = 0;

            for (int index = 0; index < 10; index++) {
                GLib.Object? band = ((Gst.ChildProxy) element).get_child_by_index (index);

                float freq = freqs[index];
                float bandwidth = freq - last_freq;

                last_freq = freq;
                band.set ("freq", freq,
                          "bandwidth", bandwidth,
                          "gain", 0.0f);
            }
        }

        public void set_gain (int index, double gain) {
            GLib.Object? band = ((Gst.ChildProxy) element).get_child_by_index (index);

            if (gain < 0) {
                gain *= 0.24f;
            } else {
                gain *= 0.12f;
            }

            band.set ("gain", gain);
        }
    }
}
