// SPDX-License-Identifier: GPL-3.0-or-later
namespace SystemMonitor {

    /**
     * Fixed-capacity history of samples. Pushing into a full buffer
     * overwrites the oldest sample, so memory use never grows and push()
     * never allocates.
     */
    public class RingBuffer {
        private double[] data;
        private int next = 0;       // slot the next push() writes to
        private int stored = 0;     // number of valid samples held
        private int _capacity;

        public int capacity {
            get { return _capacity; }
        }

        public int count {
            get { return stored; }
        }

        public RingBuffer(int capacity) {
            assert(capacity > 0);
            _capacity = capacity;
            data = new double[capacity];
        }

        public void push(double value) {
            data[next] = value;
            next = (next + 1) % _capacity;
            if (stored < _capacity) {
                stored++;
            }
        }

        /** Sample number `index`, where 0 is the oldest sample still stored. */
        public double get(int index) {
            assert(index >= 0 && index < stored);
            // Not yet full: oldest is slot 0. Full: oldest is the slot
            // that the next push() is about to overwrite.
            int oldest = (stored < _capacity) ? 0 : next;
            return data[(oldest + index) % _capacity];
        }
    }
}