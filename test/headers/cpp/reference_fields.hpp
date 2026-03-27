#pragma once

namespace Tests {
struct ReferenceField
{
  explicit ReferenceField(int& input) : ref(input)
  {
  }

  int& ref;
  int value = 7;
};
} // namespace Tests
