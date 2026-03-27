#pragma once

#include <vector>

namespace Tests {
template<typename T>
class Array
{
public:
  using HT = T;

  explicit Array(const std::vector<HT>& values);
};
}
