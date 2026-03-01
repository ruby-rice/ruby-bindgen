#include <version_guards.hpp>
#include "version_guards-rb.hpp"

using namespace Rice;



void Init_VersionGuards()
{
  Module rb_mGuards = define_module("Guards");

  Rice::Data_Type<Guards::MyClass> rb_cGuardsMyClass = define_class_under<Guards::MyClass>(rb_mGuards, "MyClass")
    .define_constructor(Constructor<Guards::MyClass>())
    .define_method<void(Guards::MyClass::*)()>("existing_method", &Guards::MyClass::existingMethod)
    .define_method<void(Guards::MyClass::*)(int)>("overloaded", &Guards::MyClass::overloaded,
      Arg("x"))
    .define_constant("EXISTING_CONST", (int)Guards::MyClass::EXISTING_CONST)
    #if TEST_VERSION >= 20000
    .define_constructor(Constructor<Guards::MyClass, int, bool>(),
      Arg("x"), Arg("flag"))
    .define_method<void(Guards::MyClass::*)()>("new_method", &Guards::MyClass::newMethod)
    .define_method<void(Guards::MyClass::*)(int, bool)>("overloaded", &Guards::MyClass::overloaded,
      Arg("x"), Arg("flag"))
    .define_constant("NEW_CONST", (int)Guards::MyClass::NEW_CONST)
    #endif
    ;
  rb_mGuards.define_constant("EXISTING_FLAG", (int)Guards::EXISTING_FLAG);
  #if TEST_VERSION >= 20000
  rb_mGuards.define_constant("NEW_FLAG", (int)Guards::NEW_FLAG);
  #endif
  #if TEST_VERSION >= 20000
  rb_mGuards.define_module_function<void(*)(int)>("new_function", &Guards::newFunction,
    Arg("x"));

  #endif
}
