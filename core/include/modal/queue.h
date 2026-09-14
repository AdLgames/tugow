// The bridge between the physics thread and the audio thread.
//
// Single producer, single consumer, lock free, fixed capacity, no allocation
// anywhere. The physics thread writes; the audio callback reads. Neither
// waits for the other, because the audio callback may never wait for
// anything.
#pragma once

#include <atomic>
#include <cstdint>

namespace modal {

enum class ContactType : uint8_t {
    Impact = 0,
    Roll = 1,
    Scrape = 2,
    Release = 3,
};

struct ContactEvent {
    uint32_t model_id = 0;    // index into the loaded model table
    uint32_t voice_hint = 0;  // 0 for a new voice, else continue that one
    float impulse = 0.0f;     // N.s, for impacts
    float normal_force = 0.0f;
    float tangential_vel = 0.0f;
    float contact_u = 0.0f, contact_v = 0.0f;  // normalised strike position
    float pan = 0.0f, distance = 0.0f;
    ContactType type = ContactType::Impact;
    uint8_t _pad[3] = {};
};

// The build plan asserts 48 here. Two uint32, seven float, one uint8 and
// three bytes of padding is 40, and there is no trailing padding at four
// byte alignment, so 48 was never reachable without padding put there on
// purpose. Nothing wants it to be 48, so this says what it is.
static_assert(sizeof(ContactEvent) == 40, "ContactEvent has changed size");

// Capacity is fixed at construction and is a power of two so the wrap is a
// mask rather than a division.
template <uint32_t Capacity>
class ContactQueue {
    static_assert(Capacity > 0 && (Capacity & (Capacity - 1)) == 0,
                  "capacity must be a power of two");

public:
    // Producer side. False when full — the caller decides what to drop, and
    // it should be deciding before it gets here. See the note below.
    bool push(const ContactEvent& event) {
        const uint32_t head = head_.load(std::memory_order_relaxed);
        const uint32_t next = (head + 1) & kMask;
        if (next == tail_.load(std::memory_order_acquire)) {
            dropped_.fetch_add(1, std::memory_order_relaxed);
            return false;
        }
        events_[head] = event;
        head_.store(next, std::memory_order_release);
        return true;
    }

    // Consumer side. False when empty.
    bool pop(ContactEvent& out) {
        const uint32_t tail = tail_.load(std::memory_order_relaxed);
        if (tail == head_.load(std::memory_order_acquire)) return false;
        out = events_[tail];
        tail_.store((tail + 1) & kMask, std::memory_order_release);
        return true;
    }

    uint32_t dropped() const { return dropped_.load(std::memory_order_relaxed); }
    void clear_dropped() { dropped_.store(0, std::memory_order_relaxed); }

    bool empty() const {
        return head_.load(std::memory_order_acquire) == tail_.load(std::memory_order_acquire);
    }

    uint32_t size() const {
        const uint32_t head = head_.load(std::memory_order_acquire);
        const uint32_t tail = tail_.load(std::memory_order_acquire);
        return (head - tail) & kMask;
    }

    static constexpr uint32_t capacity() { return Capacity - 1; }

private:
    static constexpr uint32_t kMask = Capacity - 1;
    ContactEvent events_[Capacity];
    std::atomic<uint32_t> head_{0};
    std::atomic<uint32_t> tail_{0};
    std::atomic<uint32_t> dropped_{0};
};

// The build plan says that on overflow the queue should drop the quietest
// pending event rather than the newest. It cannot: entries already in the
// ring may be being read by the audio thread this instant, and rewriting one
// from the producer is a data race — the one thing this structure exists to
// avoid. A lock-free ring can refuse a write; it cannot reach back into
// itself.
//
// The intent is right, and belongs one step earlier. The producer already
// has to cap its output per tick, so it sorts what it has by impulse and
// pushes the loudest. Same outcome, no race: see sort_loudest_first.
void sort_loudest_first(ContactEvent* events, int count);

}  // namespace modal
