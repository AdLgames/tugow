#include "json.h"

#include <cctype>
#include <cstdlib>

namespace modal {
namespace json {
namespace {

const Value kNull;

class Parser {
public:
    Parser(const std::string& text) : text_(text) {}

    bool parse(Value& out) {
        skip();
        if (!value(out, 0)) return false;
        skip();
        if (at_ != text_.size()) return fail("trailing characters");
        return true;
    }

    std::string error;

private:
    const std::string& text_;
    size_t at_ = 0;

    bool fail(const std::string& what) {
        if (error.empty()) error = what + " at byte " + std::to_string(at_);
        return false;
    }

    void skip() {
        while (at_ < text_.size() && std::isspace(static_cast<unsigned char>(text_[at_]))) ++at_;
    }

    bool literal(const char* word) {
        const size_t n = std::string(word).size();
        if (text_.compare(at_, n, word) != 0) return fail("unexpected token");
        at_ += n;
        return true;
    }

    // Depth is capped so a pathological file cannot blow the stack. A .modal
    // file is three levels deep; anything near the limit is not one.
    bool value(Value& out, int depth) {
        if (depth > 32) return fail("nested too deeply");
        if (at_ >= text_.size()) return fail("unexpected end of input");
        switch (text_[at_]) {
            case '{': return object(out, depth);
            case '[': return array(out, depth);
            case '"':
                out.type = Value::Type::String;
                return string(out.string);
            case 't':
                out.type = Value::Type::Bool;
                out.boolean = true;
                return literal("true");
            case 'f':
                out.type = Value::Type::Bool;
                out.boolean = false;
                return literal("false");
            case 'n':
                out.type = Value::Type::Null;
                return literal("null");
            default: return number(out);
        }
    }

    bool object(Value& out, int depth) {
        out.type = Value::Type::Object;
        ++at_;  // {
        skip();
        if (at_ < text_.size() && text_[at_] == '}') { ++at_; return true; }
        for (;;) {
            skip();
            std::string key;
            if (at_ >= text_.size() || text_[at_] != '"') return fail("expected a key");
            if (!string(key)) return false;
            skip();
            if (at_ >= text_.size() || text_[at_] != ':') return fail("expected ':'");
            ++at_;
            skip();
            Value child;
            if (!value(child, depth + 1)) return false;
            out.object[key] = child;
            skip();
            if (at_ >= text_.size()) return fail("unterminated object");
            if (text_[at_] == ',') { ++at_; continue; }
            if (text_[at_] == '}') { ++at_; return true; }
            return fail("expected ',' or '}'");
        }
    }

    bool array(Value& out, int depth) {
        out.type = Value::Type::Array;
        ++at_;  // [
        skip();
        if (at_ < text_.size() && text_[at_] == ']') { ++at_; return true; }
        for (;;) {
            skip();
            Value child;
            if (!value(child, depth + 1)) return false;
            out.array.push_back(child);
            skip();
            if (at_ >= text_.size()) return fail("unterminated array");
            if (text_[at_] == ',') { ++at_; continue; }
            if (text_[at_] == ']') { ++at_; return true; }
            return fail("expected ',' or ']'");
        }
    }

    bool string(std::string& out) {
        ++at_;  // opening quote
        out.clear();
        while (at_ < text_.size()) {
            const char c = text_[at_++];
            if (c == '"') return true;
            if (c != '\\') { out.push_back(c); continue; }
            if (at_ >= text_.size()) break;
            switch (text_[at_++]) {
                case '"': out.push_back('"'); break;
                case '\\': out.push_back('\\'); break;
                case '/': out.push_back('/'); break;
                case 'b': out.push_back('\b'); break;
                case 'f': out.push_back('\f'); break;
                case 'n': out.push_back('\n'); break;
                case 'r': out.push_back('\r'); break;
                case 't': out.push_back('\t'); break;
                case 'u':
                    // Kept as the literal escape. No .modal field is
                    // displayed to a user, so decoding it would be work for
                    // nobody, and dropping it silently would be worse.
                    if (at_ + 4 > text_.size()) return fail("truncated \\u escape");
                    out.append("\\u");
                    out.append(text_, at_, 4);
                    at_ += 4;
                    break;
                default: return fail("unknown escape");
            }
        }
        return fail("unterminated string");
    }

    bool number(Value& out) {
        const char* start = text_.c_str() + at_;
        char* end = nullptr;
        const double parsed = std::strtod(start, &end);
        if (end == start) return fail("expected a value");
        at_ += static_cast<size_t>(end - start);
        out.type = Value::Type::Number;
        out.number = parsed;
        return true;
    }
};

}  // namespace

const Value& Value::operator[](const std::string& key) const {
    const auto found = object.find(key);
    return found == object.end() ? kNull : found->second;
}

bool Value::has(const std::string& key) const {
    return object.find(key) != object.end();
}

bool parse(const std::string& text, Value& out, std::string& error) {
    Parser parser(text);
    if (parser.parse(out)) return true;
    error = parser.error;
    return false;
}

}  // namespace json
}  // namespace modal
