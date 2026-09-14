// The queue is the one place two threads meet, so it is stress tested rather
// than reasoned about. A race here is a crackle on one user's machine and
// nowhere else.
#include "doctest.h"

#include <atomic>
#include <thread>
#include <vector>

#include "modal/queue.h"

TEST_CASE("the event struct is the size it says it is") {
    CHECK(sizeof(modal::ContactEvent) == 40);
}

TEST_CASE("events come out in the order they went in") {
    modal::ContactQueue<64> queue;
    CHECK(queue.empty());
    for (int i = 0; i < 10; ++i) {
        modal::ContactEvent event;
        event.model_id = static_cast<uint32_t>(i);
        CHECK(queue.push(event));
    }
    CHECK(queue.size() == 10);
    for (int i = 0; i < 10; ++i) {
        modal::ContactEvent event;
        REQUIRE(queue.pop(event));
        CHECK(event.model_id == static_cast<uint32_t>(i));
    }
    CHECK(queue.empty());
    modal::ContactEvent nothing;
    CHECK_FALSE(queue.pop(nothing));
}

TEST_CASE("a full queue refuses rather than overwrites") {
    modal::ContactQueue<8> queue;
    int accepted = 0;
    for (int i = 0; i < 20; ++i) {
        modal::ContactEvent event;
        event.model_id = static_cast<uint32_t>(i);
        if (queue.push(event)) ++accepted;
    }
    CHECK(accepted == static_cast<int>(queue.capacity()));
    CHECK(queue.dropped() == 20u - queue.capacity());

    // And what survived is the oldest, unaltered — the refusal must not have
    // corrupted anything already in there.
    for (int i = 0; i < accepted; ++i) {
        modal::ContactEvent event;
        REQUIRE(queue.pop(event));
        CHECK(event.model_id == static_cast<uint32_t>(i));
    }
}

TEST_CASE("the ring wraps without losing anything") {
    modal::ContactQueue<8> queue;
    uint32_t written = 0, read = 0;
    for (int round = 0; round < 100; ++round) {
        for (int i = 0; i < 5; ++i) {
            modal::ContactEvent event;
            event.model_id = written;
            if (queue.push(event)) ++written;
        }
        for (int i = 0; i < 5; ++i) {
            modal::ContactEvent event;
            if (!queue.pop(event)) break;
            CHECK(event.model_id == read);
            ++read;
        }
    }
    CHECK(read == written);
    CHECK(read > 400u);
}

TEST_CASE("a million events cross between two threads intact") {
    // One producer, one consumer, no locks. Ordering and content both have
    // to survive; a torn event would show as a model_id that never went in.
    modal::ContactQueue<1024> queue;
    constexpr uint32_t kCount = 1000000;
    std::atomic<bool> failed{false};
    std::atomic<uint32_t> received{0};

    std::thread consumer([&] {
        uint32_t expected = 0;
        while (expected < kCount) {
            modal::ContactEvent event;
            if (!queue.pop(event)) {
                std::this_thread::yield();
                continue;
            }
            // Every field is checked, not just the counter: a torn write
            // would leave one of them from a different event.
            if (event.model_id != expected || event.voice_hint != expected + 1 ||
                event.impulse != static_cast<float>(expected % 1000)) {
                failed = true;
                return;
            }
            ++expected;
            received = expected;
        }
    });

    uint32_t sent = 0;
    while (sent < kCount) {
        modal::ContactEvent event;
        event.model_id = sent;
        event.voice_hint = sent + 1;
        event.impulse = static_cast<float>(sent % 1000);
        if (queue.push(event)) ++sent;
    }
    consumer.join();

    CHECK_FALSE(failed.load());
    CHECK(received.load() == kCount);
}

TEST_CASE("the producer's own ordering is what drops the quietest") {
    // The plan asks the queue to drop the quietest pending event. It cannot:
    // an entry already in the ring may be being read this instant. The
    // producer sorts before pushing instead, which is the same outcome from
    // the only side that can safely do it.
    modal::ContactEvent events[5];
    const float impulses[] = {0.2f, 5.0f, 0.1f, 3.0f, 1.0f};
    for (int i = 0; i < 5; ++i) {
        events[i].impulse = impulses[i];
        events[i].type = modal::ContactType::Impact;
    }
    modal::sort_loudest_first(events, 5);
    CHECK(events[0].impulse == doctest::Approx(5.0f));
    CHECK(events[4].impulse == doctest::Approx(0.1f));

    // Truncating to two keeps the two loudest, which is the point.
    modal::ContactQueue<4> queue;
    for (int i = 0; i < 2; ++i) CHECK(queue.push(events[i]));
    modal::ContactEvent out;
    REQUIRE(queue.pop(out));
    CHECK(out.impulse == doctest::Approx(5.0f));
}

TEST_CASE("continuous contacts are ranked on force, impacts on impulse") {
    modal::ContactEvent events[2];
    events[0].type = modal::ContactType::Roll;
    events[0].normal_force = 9.0f;
    events[0].impulse = 0.0f;
    events[1].type = modal::ContactType::Impact;
    events[1].impulse = 4.0f;
    modal::sort_loudest_first(events, 2);
    CHECK(events[0].type == modal::ContactType::Roll);
}
