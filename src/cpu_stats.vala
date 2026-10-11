// SPDX-License-Identifier: GPL-3.0-or-later
namespace SystemMonitor {

    /**
     * One snapshot of the cumulative CPU time counters from the aggregate
     * "cpu" line of /proc/stat. Units are USER_HZ ticks (normally 1/100 s),
     * summed over all logical CPUs, counting up since boot.
     */
    public class CpuTimes {
        public uint64 user;
        public uint64 nice;
        public uint64 system;
        public uint64 idle;
        public uint64 iowait;
        public uint64 irq;
        public uint64 softirq;
        public uint64 steal;

        /* guest and guest_nice are deliberately NOT stored: the kernel
         * already counts guest time inside user and nice, so adding them
         * again would count the same ticks twice. */

        /** Time the CPUs did nothing, including waiting for I/O. */
        public uint64 idle_all {
            get { return idle + iowait; }
        }

        /** All accounted time. */
        public uint64 total {
            get { return idle_all + user + nice + system + irq + softirq + steal; }
        }

        /**
         * Extracts the aggregate "cpu" line from the full text of
         * /proc/stat. Returns null if it is missing or malformed.
         */
        public static CpuTimes? parse(string stat_contents) {
            foreach (string line in stat_contents.split("\n")) {
                // "cpu " (with the space) is the aggregate line; the
                // per-core lines are "cpu0", "cpu1", ...
                if (line.has_prefix("cpu ")) {
                    return parse_aggregate_line(line);
                }
            }
            return null;
        }

        private static CpuTimes? parse_aggregate_line(string line) {
            uint64[] counters = {};
            bool seen_label = false;

            foreach (string token in line.split(" ")) {
                if (token == "") {
                    continue;               // kernel pads with two spaces
                }
                if (!seen_label) {
                    seen_label = true;      // skip the "cpu" label itself
                    continue;
                }
                uint64 value;
                if (!parse_counter(token, out value)) {
                    return null;
                }
                counters += value;
            }

            // user, nice, system, idle are the minimum we need.
            if (counters.length < 4) {
                return null;
            }

            var times = new CpuTimes();
            times.user    = counters[0];
            times.nice    = counters[1];
            times.system  = counters[2];
            times.idle    = counters[3];
            // Newer kernels add more fields; absent ones count as 0.
            times.iowait  = field_or_zero(counters, 4);
            times.irq     = field_or_zero(counters, 5);
            times.softirq = field_or_zero(counters, 6);
            times.steal   = field_or_zero(counters, 7);
            return times;
        }

        private static uint64 field_or_zero(uint64[] counters, int index) {
            if (index < counters.length) {
                return counters[index];
            }
            return 0;
        }

        /* Strict decimal parser. uint64.parse() returns 0 for garbage,
         * which would turn a malformed file into valid-looking numbers. */
        private static bool parse_counter(string token, out uint64 value) {
            value = 0;
            if (token.length == 0) {
                return false;
            }
            for (int i = 0; i < token.length; i++) {
                if (token[i] < '0' || token[i] > '9') {
                    return false;
                }
            }
            value = uint64.parse(token, 10);
            return true;
        }
    }

    /**
     * Turns a stream of cumulative CpuTimes snapshots into utilisation
     * percentages. 0-100 is relative to ALL logical CPUs combined:
     * 100% means every core was fully busy.
     */
    public class CpuUsageCalculator {
        private CpuTimes? previous = null;

        /**
         * Feeds in a new snapshot. Returns true and sets percent when a
         * trustworthy value exists; otherwise returns false and percent
         * must not be displayed.
         */
        public bool update(CpuTimes current, out double percent) {
            percent = 0.0;

            // First sample: nothing to compare against yet.
            if (previous == null) {
                previous = current;
                return false;
            }

            // Counters only grow. If they went backwards (CPU hot-unplug,
            // odd resume behaviour), restart from this snapshot.
            if (current.total < previous.total
                || current.idle_all < previous.idle_all) {
                previous = current;
                return false;
            }

            uint64 total_delta = current.total - previous.total;
            uint64 idle_delta = current.idle_all - previous.idle_all;

            // No ticks elapsed (sampled faster than USER_HZ). Keep the old
            // baseline so the next sample covers a longer interval.
            if (total_delta == 0) {
                return false;
            }

            // Busy time can't shrink. If it did, the data is inconsistent.
            if (idle_delta > total_delta) {
                previous = current;
                return false;
            }

            previous = current;
            percent = 100.0 * (double) (total_delta - idle_delta)
                      / (double) total_delta;
            return true;
        }
    }
}