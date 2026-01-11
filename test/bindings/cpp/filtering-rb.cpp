#include <filtering.hpp>
#include "filtering-rb.hpp"

using namespace Rice;

Rice::Class rb_cOuterClassWithDeprecatedConstructor;
Rice::Class rb_cOuterClassWithDeprecatedConversion;
Rice::Class rb_cOuterMyClass;
Rice::Class rb_cOuterOtherClass;

void Init_Filtering()
{
  Module rb_mOuter = define_module("Outer");

  rb_mOuter.define_module_function("exported_function", &Outer::exportedFunction);

  rb_mOuter.define_module_function("normal_function", &Outer::normalFunction);

  rb_mOuter.define_module_function<void(*)(const char*)>("print_formatted", &Outer::printFormatted,
    Arg("msg"));

  rb_cOuterMyClass = define_class_under<Outer::MyClass>(rb_mOuter, "MyClass").
    define_constructor(Constructor<Outer::MyClass>()).
    define_method("new_method", &Outer::MyClass::newMethod);

  rb_cOuterClassWithDeprecatedConstructor = define_class_under<Outer::ClassWithDeprecatedConstructor>(rb_mOuter, "ClassWithDeprecatedConstructor").
    define_constructor(Constructor<Outer::ClassWithDeprecatedConstructor, int, int>(),
      Arg("param1"), Arg("param2")).
    define_method("do_something", &Outer::ClassWithDeprecatedConstructor::doSomething);

  rb_cOuterOtherClass = define_class_under<Outer::OtherClass>(rb_mOuter, "OtherClass").
    define_constructor(Constructor<Outer::OtherClass>());

  rb_cOuterClassWithDeprecatedConversion = define_class_under<Outer::ClassWithDeprecatedConversion>(rb_mOuter, "ClassWithDeprecatedConversion").
    define_constructor(Constructor<Outer::ClassWithDeprecatedConversion>()).
    define_method("to_i", [](const Outer::ClassWithDeprecatedConversion& self) -> int
    {
      return self;
    });
}