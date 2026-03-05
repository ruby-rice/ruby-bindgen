#include "myproject-rb.hpp"

#include "./unions-rb.hpp"

extern "C"
void Init_myproject()
{
  return Rice::detail::cpp_protect([]
  {
      Init_Unions();
  });
}