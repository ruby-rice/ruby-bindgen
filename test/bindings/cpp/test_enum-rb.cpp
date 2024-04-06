#include "test_enum-rb.hpp"

#include "./enum-rb.hpp"

extern "C"
void Init_test_enum()
{
  return Rice::detail::cpp_protect([]
  {
      Init_Enum();
  });
}