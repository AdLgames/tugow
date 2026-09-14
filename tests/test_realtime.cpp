// The audio callback may not allocate. Not "should not" — a malloc inside a
// callback takes a lock that the memory allocator shares with every other
// thread in the process, and when that lock is held the audio thread misses
// its deadline and the user hears a crackle. On one machine. Sometimes.
//
// So it is checked mechanically rather than by reading the code: every
// global allocation is counted, and the count may not move while the mix is
// running.
#include "doctest.h"

#include <atomic>
#include <cstdlib>
#include <new>
#include <vector>

#include "modal/model.h"
#include "modal/voice.h"

namespace {
std::atomic<int> g_allocations{0};
std::atomic<bool> g_watching{false};
}  // namespace

void* operator new(std::size_t size) {
    if (g_watching.load(std::memory_order_relaxed)) {
        g_allocations.fetch_add(1, std::memory_order_relaxed);
    }
    void* memory = std::malloc(size == 0 ? 1 : size);
    if (memory == nullptr) throw std::bad_alloc();
    return memory;
}

void operator delete(void* memory) noexcept { std::free(memory); }
void operator delete(void* memory, std::size_t) noexcept { std::free(memory); }
void* operator new[](std::size_t size) { return operator new(size); }
void operator delete[](void* memory) noexcept { std::free(memory); }
void operator delete[](void* memory, std::size_t) noexcept { std::free(memory); }

TEST_CASE("the counter notices an allocation") {
    // Or the case below would pass by being broken.
    g_allocations = 0;
    g_watching = true;
    volatile int* leak = new int(4);
    g_watching = false;
    CHECK(g_allocations.load() > 0);
    delete leak;
}

TEST_CASE("mixing allocates nothing, however busy the pool") {
    modal::Model model;
    for (int i = 0; i < 16; ++i) {
        model.modes.push_back({400.0 + 317.0 * i, 1.2 / (1.0 + 0.4 * i), 1.0 / (1.0 + i)});
    }
    const modal::Model* models[] = {&model};

    modal::VoicePool pool;
    pool.resize(modal::kMaxVoices, 48000.0);  // allocates, on purpose, here
    pool.set_models(models, 1);

    std::vector<float> out(1024, 0.0f);

    g_allocations = 0;
    g_watching = true;
    for (int block = 0; block < 200; ++block) {
        // Starting voices is part of the callback's work: the queue is
        // drained from _mix, so allocation there would count too.
        for (int i = 0; i < 4; ++i) {
            modal::ContactEvent event;
            event.model_id = 0;
            event.impulse = 1.0f + i;
            event.distance = static_cast<float>(block % 60);
            event.type = modal::ContactType::Impact;
            pool.start(event);
        }
        std::fill(out.begin(), out.end(), 0.0f);
        pool.mix(out.data(), 1024);
    }
    g_watching = false;

    CHECK(g_allocations.load() == 0);
}

TEST_CASE("a block larger than the scratch is worked in pieces, not grown") {
    modal::Model model;
    model.modes.push_back({1000.0, 0.5, 1.0});
    const modal::Model* models[] = {&model};
    modal::VoicePool pool;
    pool.resize(32, 48000.0);
    pool.set_models(models, 1);
    modal::ContactEvent event;
    event.impulse = 1.0f;
    pool.start(event);

    // Deliberately past the internal scratch size.
    std::vector<float> out(8192, 0.0f);
    g_allocations = 0;
    g_watching = true;
    pool.mix(out.data(), 8192);
    g_watching = false;
    CHECK(g_allocations.load() == 0);

    bool anything = false;
    for (float sample : out) {
        if (sample != 0.0f) anything = true;
    }
    CHECK(anything);
}
