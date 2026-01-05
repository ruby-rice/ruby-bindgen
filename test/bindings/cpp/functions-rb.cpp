#include <functions.hpp>
#include "functions-rb.hpp"

using namespace Rice;


void Init_Functions()
{
  define_global_function("some_function", &someFunction,
    Arg("a"));
  
  define_global_function<void(*)(int)>("overload", &overload,
    Arg("a"));
  
  define_global_function<void(*)(int, int)>("overload", &overload,
    Arg("a"), Arg("b"));
  
  define_global_function<void(*)(int, int, int)>("overload", &overload,
    Arg("a"), Arg("b"), Arg("c") = static_cast<int>(10));

}