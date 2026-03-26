#pragma once

#include <cstddef>

namespace Tests {
template<std::size_t I, typename Target, typename First, typename... Remaining>
class TypeListIndexHelper
{
public:
  static constexpr bool is_same = false;
  static constexpr std::size_t value = I;
};

template<typename Target, typename... Types>
class TypeListIndex
{
public:
  static constexpr std::size_t value = TypeListIndexHelper<0, Target, Types...>::value;
};
}
