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

  define_global_function("get_const_string", &getConstString).
    define_return(ReturnBuffer());

  define_global_function<void(*)(const char*)>("process_string", &processString,
    ArgBuffer("str"));

  define_global_function<void(*)(const char* const, int)>("process_string", &processString,
    ArgBuffer("str"), Arg("len"));

  define_global_function("unnamed_params", &unnamedParams,
    Arg("arg_0"), Arg("arg_1"), Arg("arg_2"));

  define_global_function("mixed_params", &mixedParams,
    Arg("named"), Arg("arg_1"), Arg("also_named"), Arg("arg_3"));

  define_global_function("empty?", &isEmpty);

  define_global_function("valid?", &isValid);

  define_global_function("has_data?", &hasData);

  define_global_function("check_value", &checkValue,
    Arg("x"));

  define_global_function("validate", &validate,
    Arg("x"));

  define_global_function("process", &process,
    Arg("a"), Arg("b"));

  Rice::Data_Type<Widget> rb_cWidget = define_class<Widget>("Widget").
    define_constructor(Constructor<Widget>()).
    define_method("empty?", &Widget::empty).
    define_method("enabled?", &Widget::isEnabled).
    define_method("contains", &Widget::contains,
      Arg("x")).
    define_method("try_set", &Widget::trySet,
      Arg("value"));
}