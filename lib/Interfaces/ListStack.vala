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
    public abstract class Interfaces.ListStack : Interfaces.StackWrapper {
        protected Gee.HashMap<uint, Gtk.TreeIter?> iter_hash;

        public abstract int add_iter (CObjects.Media m);
        public abstract int remove_iter (uint tid);

        public new void select_run_row (uint tid) {
            if (iter_hash.has_key (tid) && has_list_view) {
                var iter = iter_hash[tid];
                var stack_wrapper = this as Interfaces.StackWrapper;
                if (stack_wrapper != null) {
                    stack_wrapper.select_run_row (iter);
                }
            }
        }

        public new void remove_run_icon (uint tid) {
            if (iter_hash.has_key (tid) && has_list_view) {
                var stack_wrapper = this as Interfaces.StackWrapper;
                if (stack_wrapper != null) {
                    var iter = iter_hash[tid];
                    stack_wrapper.remove_run_icon (iter);
                }
            }
        }

        public new void scroll_to_current (uint tid) {
            if (iter_hash.has_key (tid) && has_list_view) {
                var stack_wrapper = this as Interfaces.StackWrapper;
                if (stack_wrapper != null) {
                    var iter = iter_hash[tid];
                    stack_wrapper.scroll_to_current (iter);
                }
            }
        }
    }
}
