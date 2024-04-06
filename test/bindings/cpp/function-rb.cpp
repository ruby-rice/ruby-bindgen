#include <function.hpp>
#include "function-rb.hpp"

using namespace Rice;


void Init_Function()
{
  define_global_function("some_function", &someFunction,
    Arg("a"));
  
  define_global_function<void(*)(int)>("overload", &overload,
    Arg("a"));
  
  define_global_function<void(*)(float)>("overload", &overload,
    Arg("a"));

}