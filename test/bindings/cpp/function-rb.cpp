#include <function.hpp>
#include "function-rb.hpp"

using namespace Rice;



extern "C"
void Init_Function()
{
  define_global_function<void(*)(float)>("some_function", &someFunction);
  
  define_global_function<void(*)(int)>("overload", &overload);
  
  define_global_function<void(*)(float)>("overload", &overload);

}