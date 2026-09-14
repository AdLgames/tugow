// A JSON reader small enough to vendor, because core has no dependencies.
//
// It covers what a .modal file is: objects, arrays, numbers, strings, bools
// and null. No comments, no trailing commas, no surrogate pairs. Enough to
// parse the format and to reject a file that is not one.
#pragma once

#include <map>
#include <string>
#include <vector>

namespace modal {
namespace json {

class Value {
public:
    enum class Type { Null, Bool, Number, String, Array, Object };

    Type type = Type::Null;
    bool boolean = false;
    double number = 0.0;
    std::string string;
    std::vector<Value> array;
    std::map<std::string, Value> object;

    bool is_number() const { return type == Type::Number; }
    bool is_string() const { return type == Type::String; }
    bool is_array() const { return type == Type::Array; }
    bool is_object() const { return type == Type::Object; }

    // Missing keys come back as a null Value rather than throwing, so the
    // loader can report every problem with a file instead of the first.
    const Value& operator[](const std::string& key) const;
    bool has(const std::string& key) const;
};

// Returns false and fills `error` on malformed input.
bool parse(const std::string& text, Value& out, std::string& error);

}  // namespace json
}  // namespace modal
