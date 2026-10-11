// SPDX-License-Identifier: GPL-3.0-or-later
using SystemMonitor;

void test_starts_empty() {
    var rb = new RingBuffer(3);
    assert(rb.count == 0);
    assert(rb.capacity == 3);
}

void test_below_capacity_keeps_insertion_order() {
    var rb = new RingBuffer(3);
    rb.push(1.0);
    rb.push(2.0);
    assert(rb.count == 2);
    assert(rb[0] == 1.0);
    assert(rb[1] == 2.0);
}

void test_exactly_full() {
    var rb = new RingBuffer(3);
    rb.push(1.0);
    rb.push(2.0);
    rb.push(3.0);
    assert(rb.count == 3);
    assert(rb[0] == 1.0);
    assert(rb[2] == 3.0);
}

void test_overwrites_oldest_when_full() {
    var rb = new RingBuffer(3);
    for (int i = 1; i <= 5; i++) {
        rb.push(i);
    }
    assert(rb.count == 3);
    assert(rb[0] == 3.0);   // 1 and 2 were overwritten
    assert(rb[1] == 4.0);
    assert(rb[2] == 5.0);
}

int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/ring_buffer/empty", test_starts_empty);
    Test.add_func("/ring_buffer/below_capacity", test_below_capacity_keeps_insertion_order);
    Test.add_func("/ring_buffer/exactly_full", test_exactly_full);
    Test.add_func("/ring_buffer/wraps", test_overwrites_oldest_when_full);
    return Test.run();
}