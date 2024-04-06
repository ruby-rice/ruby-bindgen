#include "test_constructors-rb.hpp"

#include "./constructors-rb.hpp"

extern "C"
void Init_test_constructors()
{
  return Rice::detail::cpp_protect([]
  {
      Init_Constructors();
  });
}