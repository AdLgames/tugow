#include "modal/queue.h"

#include <algorithm>

namespace modal {

void sort_loudest_first(ContactEvent* events, int count) {
    // Continuous contacts are sorted on the force holding them, impacts on
    // the blow that started them, so the two are comparable enough to rank.
    std::sort(events, events + count, [](const ContactEvent& x, const ContactEvent& y) {
        const float x_weight = x.type == ContactType::Impact ? x.impulse : x.normal_force;
        const float y_weight = y.type == ContactType::Impact ? y.impulse : y.normal_force;
        return x_weight > y_weight;
    });
}

}  // namespace modal
