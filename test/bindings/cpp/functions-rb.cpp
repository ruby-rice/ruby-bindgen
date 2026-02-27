#include <functions.hpp>
#include "functions-rb.hpp"

using namespace Rice;

#include "functions-rb.ipp"

void Init_Functions()
{
  define_global_function<void(*)(float)>("some_function", &someFunction,
    Arg("a"));

  define_global_function<void(*)(int)>("overload", &overload,
    Arg("a"));

  define_global_function<void(*)(int, int)>("overload", &overload,
    Arg("a"), Arg("b"));

  define_global_function<void(*)(int, int, int)>("overload", &overload,
    Arg("a"), Arg("b"), Arg("c") = static_cast<int>(10));

  define_global_function<const char* const(*)()>("get_const_string", &getConstString);

  define_global_function<void(*)(const char*)>("process_string", &processString,
    Arg("str"));

  define_global_function<void(*)(const char* const, int)>("process_string", &processString,
    Arg("str"), Arg("len"));

  define_global_function<void(*)(int, float, double)>("unnamed_params", &unnamedParams,
    Arg("arg_0"), Arg("arg_1"), Arg("arg_2"));

  define_global_function<void(*)(int, float, double, int)>("mixed_params", &mixedParams,
    Arg("named"), Arg("arg_1"), Arg("also_named"), Arg("arg_3"));

  define_global_function<bool(*)()>("empty?", &isEmpty);

  define_global_function<bool(*)()>("valid?", &isValid);

  define_global_function<bool(*)()>("has_data?", &hasData);

  define_global_function<bool(*)(int)>("check_value", &checkValue,
    Arg("x"));

  define_global_function<bool(*)(int)>("validate", &validate,
    Arg("x"));

  define_global_function<bool(*)(int, int)>("process", &process,
    Arg("a"), Arg("b"));

  define_global_function<bool(*)(int)>("continuous?", &isContinuous,
    Arg("i") = static_cast<int>(-1));

  define_global_function<bool(*)(int)>("submatrix?", &isSubmatrix,
    Arg("i"));

  Rice::Data_Type<Widget> rb_cWidget = define_class<Widget>("Widget").
    define_constructor(Constructor<Widget>()).
    define_method<bool(Widget::*)()>("empty?", &Widget::empty).
    define_method<bool(Widget::*)()>("enabled?", &Widget::isEnabled).
    define_method<bool(Widget::*)(int)>("contains", &Widget::contains,
      Arg("x")).
    define_method<bool(Widget::*)(int)>("try_set", &Widget::trySet,
      Arg("value"));

  Module rb_mArrays = define_module("Arrays");

  Rice::Data_Type<arrays::Element> rb_cArraysElement = define_class_under<arrays::Element>(rb_mArrays, "Element").
    define_constructor(Constructor<arrays::Element>());

  rb_mArrays.define_module_function<void(*)(arrays::Element[4])>("process_array", &arrays::processArray,
    Arg("arr"));

  rb_mArrays.define_module_function<void(*)(const arrays::Element[4])>("process_const_array", &arrays::processConstArray,
    Arg("arr"));

  rb_mArrays.define_module_function<void(*)(arrays::Element[])>("process_incomplete_array", &arrays::processIncompleteArray,
    Arg("arr"));

  Module rb_mNontypeArgs = define_module("NontypeArgs");

  Rice::Data_Type<nontype_args::Container<double, nontype_args::Config::Size>> rb_cNontype_argsContainerDoubleNontype_argsConfigSize = Container_instantiate<double, nontype_args::Config::Size>(rb_mNontypeArgs, "ContainerDoubleNontypeArgsConfigSize");

  Rice::Data_Type<nontype_args::Config> rb_cNontypeArgsConfig = define_class_under<nontype_args::Config>(rb_mNontypeArgs, "Config").
    define_constructor(Constructor<nontype_args::Config>()).
    define_constant("Size", nontype_args::Config::Size).
    define_method<void(nontype_args::Config::*)(const nontype_args::Container<double, nontype_args::Config::Size>&)>("process", &nontype_args::Config::process,
      Arg("data"));

  Rice::Data_Type<nontype_args::User> rb_cNontypeArgsUser = define_class_under<nontype_args::User>(rb_mNontypeArgs, "User").
    define_constructor(Constructor<nontype_args::User>()).
    define_method<void(nontype_args::User::*)(const nontype_args::Container<double, nontype_args::Config::Size>&)>("use", &nontype_args::User::use,
      Arg("data"));

  Rice::Data_Type<Logger> rb_cLogger = define_class<Logger>("Logger").
    define_constructor(Constructor<Logger>()).
    define_singleton_function<void(*)(int)>("set_level", &Logger::setLevel,
      Arg("level"));

}
