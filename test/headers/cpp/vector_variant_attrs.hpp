#pragma once

#include <variant>
#include <vector>

namespace Tests {
struct Token
{
};

struct VariantVectorHolder
{
  std::vector<std::variant<int, Token>> values;
  std::vector<int> numbers;
};
} // namespace Tests
