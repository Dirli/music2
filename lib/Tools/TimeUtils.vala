namespace Music2.Tools.TimeUtils {
    public inline string pretty_timestamp_from_time (Time dt) {
        return dt.format (_("%m/%e/%Y %l:%M %p"));
    }

    public string pretty_time_from_sec (int64 s) {
        var time_fmt = "";
        var hours_val = s / 3600;
        var sec_rem = s % 3600;
        if (hours_val > 0) {
            time_fmt += "%lld ".printf (hours_val);
            time_fmt += _("h.");
        }
        if (sec_rem > 0) {
            var min_val = sec_rem / 60;
            sec_rem = sec_rem % 60;
            if (min_val > 0) {
                time_fmt += " %lld ".printf (min_val);
                time_fmt += _("m.");
            }
            if (sec_rem > 0) {
                time_fmt += " %lld ".printf (sec_rem);
                time_fmt += _("s.");
            }
        }

        return time_fmt;
    }

    public inline int64 nano_to_mili (int64 nanoseconds) {
        return nanoseconds * Constants.MILI_INV / Constants.NANO_INV;
    }

    public inline int64 micro_to_nano (int64 micro) {
        if (micro == 0) {
            return 0;
        }

        return micro * Constants.NANO_INV / Constants.MICRO_INV;
    }

    public inline int64 nano_to_sec (int64 nanoseconds) {
        if (nanoseconds == 0) {
            return 0;
        }

        return nanoseconds * Constants.SEC_INV / Constants.NANO_INV;
    }

    public inline int64 sec_to_micro (int64 seconds) {
        return seconds * Constants.MICRO_INV / Constants.SEC_INV;
    }

    public inline uint64 sec_to_nano (uint64 seconds) {
        return (uint64) (seconds * Constants.NANO_INV / Constants.SEC_INV);
    }
}
