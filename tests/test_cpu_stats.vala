// SPDX-License-Identifier: GPL-3.0-or-later
using SystemMonitor;

// Counter order: user nice system idle iowait irq softirq steal guest guest_nice
const string CPU_A = "cpu  1000 0 500 8000 100 0 20 0 0 0";
const string CPU_B = "cpu  1300 0 600 8500 100 0 20 0 0 0";
// Same work as A -> B, but with guest time (400 -> 700), which the kernel
// already includes inside "user".
const string CPU_C = "cpu  1000 0 500 8000 100 0 20 0 400 0";
const string CPU_D = "cpu  1300 0 600 8500 100 0 20 0 700 0";

// Wraps an aggregate line into a minimal but realistic /proc/stat.
string make_stat(string aggregate) {
    return aggregate + "\n" +
           "cpu0 500 0 250 4000 50 0 10 0 0 0\n" +
           "cpu1 500 0 250 4000 50 0 10 0 0 0\n" +
           "intr 12345 0 0 0\n" +
           "ctxt 987654\n" +
           "btime 1760000000\n";
}

CpuTimes sample(string aggregate) {
    CpuTimes? times = CpuTimes.parse(make_stat(aggregate));
    assert(times != null);
    return times;
}

void assert_percent(double actual, double expected) {
    double diff = actual - expected;
    if (diff < 0) {
        diff = -diff;
    }
    if (diff > 0.001) {
        error("expected %.4f%%, got %.4f%%", expected, actual);
    }
}

// Note: update() is called outside assert() on purpose. Vala can drop
// assert() expressions entirely when built with --disable-assert.

void test_parse_reads_aggregate_line() {
    CpuTimes t = sample(CPU_A);
    assert(t.user == 1000);
    assert(t.system == 500);
    assert(t.idle == 8000);
    assert(t.iowait == 100);
    assert(t.softirq == 20);
    assert(t.idle_all == 8100);
    assert(t.total == 9620);
}

void test_parse_excludes_guest_time() {
    assert(sample(CPU_C).total == 9620);
}

void test_parse_accepts_old_kernel_format() {
    CpuTimes? t = CpuTimes.parse("cpu  10 2 30 400\n");
    assert(t != null);
    assert(t.idle == 400);
    assert(t.iowait == 0);
    assert(t.total == 442);
}

void test_parse_rejects_bad_input() {
    assert(CpuTimes.parse("") == null);
    assert(CpuTimes.parse("intr 1 2 3\n") == null);        // no aggregate line
    assert(CpuTimes.parse("cpu0 1 2 3 4 5\n") == null);    // per-core line only
    assert(CpuTimes.parse("cpu  1 2 3\n") == null);        // too few fields
    assert(CpuTimes.parse("cpu  1 2 abc 4 5\n") == null);  // not a number
    assert(CpuTimes.parse("cpu  1 2 -3 4 5\n") == null);   // negative
}

void test_first_sample_has_no_value() {
    var calc = new CpuUsageCalculator();
    double percent;
    bool ok = calc.update(sample(CPU_A), out percent);
    assert(!ok);
}

void test_percent_from_two_samples() {
    var calc = new CpuUsageCalculator();
    double percent;
    bool ok = calc.update(sample(CPU_A), out percent);
    ok = calc.update(sample(CPU_B), out percent);
    assert(ok);
    assert_percent(percent, 44.4444);   // 400 busy of 900 ticks
}

void test_guest_time_is_not_double_counted() {
    var calc = new CpuUsageCalculator();
    double percent;
    bool ok = calc.update(sample(CPU_C), out percent);
    ok = calc.update(sample(CPU_D), out percent);
    assert(ok);
    assert_percent(percent, 44.4444);   // naive summing would give 58.33
}

void test_zero_delta_keeps_baseline() {
    var calc = new CpuUsageCalculator();
    double percent;
    bool ok = calc.update(sample(CPU_A), out percent);
    ok = calc.update(sample(CPU_A), out percent);   // no ticks elapsed
    assert(!ok);
    ok = calc.update(sample(CPU_B), out percent);   // still measured vs A
    assert(ok);
    assert_percent(percent, 44.4444);
}

void test_counters_going_backwards_reset_baseline() {
    var calc = new CpuUsageCalculator();
    double percent;
    bool ok = calc.update(sample(CPU_B), out percent);
    ok = calc.update(sample(CPU_A), out percent);   // counters went down
    assert(!ok);
    ok = calc.update(sample(CPU_B), out percent);
    assert(ok);
    assert_percent(percent, 44.4444);
}

void test_fully_busy_and_fully_idle() {
    var calc = new CpuUsageCalculator();
    double percent;
    bool ok = calc.update(sample(CPU_A), out percent);
    ok = calc.update(sample("cpu  2000 0 500 8000 100 0 20 0 0 0"), out percent);
    assert(ok);
    assert_percent(percent, 100.0);
    ok = calc.update(sample("cpu  2000 0 500 9000 100 0 20 0 0 0"), out percent);
    assert(ok);
    assert_percent(percent, 0.0);
}

int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/cpu_times/parse/aggregate_line", test_parse_reads_aggregate_line);
    Test.add_func("/cpu_times/parse/excludes_guest", test_parse_excludes_guest_time);
    Test.add_func("/cpu_times/parse/old_kernel", test_parse_accepts_old_kernel_format);
    Test.add_func("/cpu_times/parse/bad_input", test_parse_rejects_bad_input);
    Test.add_func("/cpu_usage/first_sample", test_first_sample_has_no_value);
    Test.add_func("/cpu_usage/two_samples", test_percent_from_two_samples);
    Test.add_func("/cpu_usage/guest_not_double_counted", test_guest_time_is_not_double_counted);
    Test.add_func("/cpu_usage/zero_delta", test_zero_delta_keeps_baseline);
    Test.add_func("/cpu_usage/counters_backwards", test_counters_going_backwards_reset_baseline);
    Test.add_func("/cpu_usage/extremes", test_fully_busy_and_fully_idle);
    return Test.run();
}