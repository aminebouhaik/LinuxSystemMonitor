// SPDX-License-Identifier: GPL-3.0-or-later
namespace SystemMonitor {

    public class SystemInfo : Object {

        private CpuUsageCalculator cpu_calculator = new CpuUsageCalculator();

        /**
         * Reads /proc/stat and computes CPU utilisation since the previous
         * call. Returns false (percent = 0) when no value is available yet
         * or the file could not be read or parsed.
         */
        public bool read_cpu_usage(out double percent) {
            percent = 0.0;

            string contents;
            try {
                FileUtils.get_contents("/proc/stat", out contents);
            } catch (FileError e) {
                warning("Cannot read /proc/stat: %s", e.message);
                return false;
            }

            CpuTimes? times = CpuTimes.parse(contents);
            if (times == null) {
                warning("Unexpected /proc/stat format");
                return false;
            }

            return cpu_calculator.update(times, out percent);
        }

        public double get_memory_usage() {
            try {
                string contents;
                FileUtils.get_contents("/proc/meminfo", out contents);

                uint64 total = 0;
                uint64 available = 0;

                foreach (string line in contents.split("\n")) {
                    if (line.has_prefix("MemTotal:")) {
                        string[] parts = line.split(" ");
                        foreach (string part in parts) {
                            if (part.strip().length > 0 &&
                                part != "MemTotal:") {
                                total = uint64.parse(part);
                                break;
                            }
                        }
                    }

                    if (line.has_prefix("MemAvailable:")) {
                        string[] parts = line.split(" ");
                        foreach (string part in parts) {
                            if (part.strip().length > 0 &&
                                part != "MemAvailable:") {
                                available = uint64.parse(part);
                                break;
                            }
                        }
                    }
                }

                if (total == 0) {
                    return 0.0;
                }

                return 100.0 *
                    ((double) (total - available) / (double) total);

            } catch (Error e) {
                warning("Cannot read memory usage: %s", e.message);
                return 0.0;
            }
        }
    }
}