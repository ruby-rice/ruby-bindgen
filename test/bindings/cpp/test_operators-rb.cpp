#include "test_operators-rb.hpp"

#include "./operators-rb.hpp"

extern "C"
void Init_test_operators()
{
  return Rice::detail::cpp_protect([]
  {
      Init_Operators();
  });
}