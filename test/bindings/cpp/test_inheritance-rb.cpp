#include "test_inheritance-rb.hpp"

#include "./inheritance-rb.hpp"

extern "C"
void Init_test_inheritance()
{
  return Rice::detail::cpp_protect([]
  {
      Init_Inheritance();
  });
}