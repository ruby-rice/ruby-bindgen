#include <sstream>
#include <class.hpp>
#include "class-rb.hpp"

using namespace Rice;



void Init_Class()
{
  Class(rb_cObject).define_constant("GLOBAL_CONSTANT", GLOBAL_CONSTANT);
  
  Class(rb_cObject).define_singleton_attr("GlobalVariable", &globalVariable)
  
  Module rb_mOuter = define_module("Outer");
  
  rb_mOuter.define_constant("NAMESPACE_CONSTANT", Outer::NAMESPACE_CONSTANT);
  
  rb_mOuter.define_singleton_attr("NamespaceVariable", &Outer::namespaceVariable)
  
  Class rb_cOuterBaseClass = define_class_under<Outer::BaseClass>(rb_mOuter, "BaseClass").
    define_constructor(Constructor<Outer::BaseClass>());
  
  Class rb_cOuterMyClass = define_class_under<Outer::MyClass, Outer::BaseClass>(rb_mOuter, "MyClass").
    define_constant("SOME_CONSTANT", Outer::MyClass::SOME_CONSTANT).
    define_singleton_attr("StaticFieldOne", &MyClass::static_field_one).
    define_singleton_function<bool(*)()>("static_method_one?", &Outer::MyClass::staticMethodOne).
    define_constructor(Constructor<Outer::MyClass>()).
    define_constructor(Constructor<Outer::MyClass, int>(),
      Arg("a")).
    define_method<void(Outer::MyClass::*)(int)>("method_one", &Outer::MyClass::methodOne,
      Arg("a")).
    define_method<void(Outer::MyClass::*)(int, bool)>("method_two", &Outer::MyClass::methodTwo,
      Arg("a"), Arg("b")).
    define_method<void(Outer::MyClass::*)(int)>("overloaded", &Outer::MyClass::overloaded,
      Arg("a")).
    define_method<void(Outer::MyClass::*)(bool)>("overloaded", &Outer::MyClass::overloaded,
      Arg("a")).
    define_attr("field_one", &Outer::MyClass::field_one);
  
  
  rb_cOuterMyClass.define_constant("HACKED_CONSTANT", Outer::MyClass::HACKED_CONSTANT);
  
  Module rb_mOuterInner = define_module_under(rb_mOuter, "Inner");
  
  Class rb_cOuterInnerContainerClass = define_class_under<Outer::Inner::ContainerClass>(rb_mOuterInner, "ContainerClass").
    define_constructor(Constructor<Outer::Inner::ContainerClass>()).
    define_attr("callback", &Outer::Inner::ContainerClass::callback).
    define_attr("config", &Outer::Inner::ContainerClass::config).
    define_attr("grid_type", &Outer::Inner::ContainerClass::gridType);
  
  Class rb_cOuterInnerContainerClassCallback = define_class_under<Outer::Inner::ContainerClass::Callback>(rb_cOuterInnerContainerClass, "Callback").
    define_constructor(Constructor<Outer::Inner::ContainerClass::Callback>()).
    define_method<bool(Outer::Inner::ContainerClass::Callback::*)() const>("compute?", &Outer::Inner::ContainerClass::Callback::compute);
  
  Class rb_cOuterInnerContainerClassConfig = define_class_under<Outer::Inner::ContainerClass::Config>(rb_cOuterInnerContainerClass, "Config").
    define_constructor(Constructor<Outer::Inner::ContainerClass::Config>()).
    define_attr("enable", &Outer::Inner::ContainerClass::Config::enable);
  
  Enum<Outer::Inner::ContainerClass::GridType> rb_cOuterInnerContainerClassGridType = define_enum_under<Outer::Inner::ContainerClass::GridType>("GridType", rb_cOuterInnerContainerClass).
    define_value("SYMMETRIC_GRID", Outer::Inner::ContainerClass::GridType::SYMMETRIC_GRID).
    define_value("ASYMMETRIC_GRID", Outer::Inner::ContainerClass::GridType::ASYMMETRIC_GRID);

}