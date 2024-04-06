#include <rice/rice.hpp>

Module rb_mMyNamespace = define_module("MyNamespace");

Class rb_cMyClass = define_class_under<MyClass>(rb_mMyNamespace, "MyClass").
  define_singleton_attr("SOME_CONSTANT", "&MyClass::SOME_CONSTANT").
  define_singleton_attr("StaticFieldOne", "&MyClass::static_field_one").
  define_singleton_function("static_method_one", &MyClass::staticMethodOne).
  define_constructor(Constructor<MyClass>).
  define_method("method_one", &MyClass::methodOne).
  define_method("method_two", &MyClass::methodTwo).
  define_attr("field_one", "&MyClass::field_one");

Class rb_cEmptyClass = define_class_under<EmptyClass>(rb_mMyNamespace, "EmptyClass");