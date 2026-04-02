#pragma once

#include <variant>
#include <vector>

namespace Tests {
struct Token
{
  bool operator==(const Token&) const
  {
    return true;
  }
};

struct VariantVectorHolder
{
  std::vector<std::variant<int, Token>> values;
  std::vector<int> numbers;
};
} // namespace Tests
