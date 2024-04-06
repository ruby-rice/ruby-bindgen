#include "test_templates-rb.hpp"

#include "./templates-rb.hpp"

extern "C"
void Init_test_templates()
{
  return Rice::detail::cpp_protect([]
  {
      Init_Templates();
  });
}