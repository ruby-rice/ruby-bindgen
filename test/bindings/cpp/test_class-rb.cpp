#include "test_class-rb.hpp"

#include "./class-rb.hpp"

extern "C"
void Init_test_class()
{
  return Rice::detail::cpp_protect([]
  {
      Init_Class();
  });
}