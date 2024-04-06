#include "test_function-rb.hpp"

#include "./function-rb.hpp"

extern "C"
void Init_test_function()
{
  return Rice::detail::cpp_protect([]
  {
      Init_Function();
  });
}