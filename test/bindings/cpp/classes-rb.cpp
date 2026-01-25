#include <classes.hpp>
#include "classes-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T>
inline void wrapper_builder(Data_Type_T& klass)
{
  klass.define_attr("item", &Outer::foobar::wrapper<T>::item);
};

void Init_Classes()
{
  Class(rb_cObject).define_constant("GLOBAL_CONSTANT", GLOBAL_CONSTANT);

  Class(rb_cObject).define_constant("GlobalVariable", globalVariable);

  Module rb_mOuter = define_module("Outer");

  rb_mOuter.define_constant("NAMESPACE_CONSTANT", Outer::NAMESPACE_CONSTANT);

  rb_mOuter.define_constant("NamespaceVariable", Outer::namespaceVariable);

  Rice::Data_Type<Outer::BaseClass> rb_cOuterBaseClass = define_class_under<Outer::BaseClass>(rb_mOuter, "BaseClass").
    define_constructor(Constructor<Outer::BaseClass>());

  Rice::Data_Type<Outer::MyClass> rb_cOuterMyClass = define_class_under<Outer::MyClass, Outer::BaseClass>(rb_mOuter, "MyClass").
    define_constant("SOME_CONSTANT", Outer::MyClass::SOME_CONSTANT).
    define_singleton_attr("StaticFieldOne", &Outer::MyClass::static_field_one).
    define_constructor(Constructor<Outer::MyClass>()).
    define_constructor(Constructor<Outer::MyClass, int>(),
      Arg("a")).
    define_method("method_one", &Outer::MyClass::methodOne,
      Arg("a")).
    define_method("method_two", &Outer::MyClass::methodTwo,
      Arg("a"), Arg("b")).
    define_method<void(Outer::MyClass::*)(int)>("overloaded", &Outer::MyClass::overloaded,
      Arg("a")).
    define_method<void(Outer::MyClass::*)(bool)>("overloaded", &Outer::MyClass::overloaded,
      Arg("a")).
    define_attr("field_one", &Outer::MyClass::field_one).
    define_singleton_function("static_method_one?", &Outer::MyClass::staticMethodOne);

  Module rb_mOuterInner = define_module_under(rb_mOuter, "Inner");

  Rice::Data_Type<Outer::Inner::ContainerClass> rb_cOuterInnerContainerClass = define_class_under<Outer::Inner::ContainerClass>(rb_mOuterInner, "ContainerClass").
    define_constructor(Constructor<Outer::Inner::ContainerClass>()).
    define_attr("callback", &Outer::Inner::ContainerClass::callback).
    define_attr("config", &Outer::Inner::ContainerClass::config).
    define_attr("grid_type", &Outer::Inner::ContainerClass::gridType);

  Rice::Data_Type<Outer::Inner::ContainerClass::Callback> rb_cOuterInnerContainerClassCallback = define_class_under<Outer::Inner::ContainerClass::Callback>(rb_cOuterInnerContainerClass, "Callback").
    define_constructor(Constructor<Outer::Inner::ContainerClass::Callback>()).
    define_method("compute?", &Outer::Inner::ContainerClass::Callback::compute);

  Rice::Data_Type<Outer::Inner::ContainerClass::Config> rb_cOuterInnerContainerClassConfig = define_class_under<Outer::Inner::ContainerClass::Config>(rb_cOuterInnerContainerClass, "Config").
    define_constructor(Constructor<Outer::Inner::ContainerClass::Config>()).
    define_attr("enable", &Outer::Inner::ContainerClass::Config::enable);

  Enum<Outer::Inner::ContainerClass::GridType> rb_cOuterInnerContainerClassGridType = define_enum_under<Outer::Inner::ContainerClass::GridType>("GridType", rb_cOuterInnerContainerClass).
    define_value("SYMMETRIC_GRID", Outer::Inner::ContainerClass::GridType::SYMMETRIC_GRID).
    define_value("ASYMMETRIC_GRID", Outer::Inner::ContainerClass::GridType::ASYMMETRIC_GRID);

  Rice::Data_Type<Outer::Inner::GpuMat> rb_cOuterInnerGpuMat = define_class_under<Outer::Inner::GpuMat>(rb_mOuterInner, "GpuMat").
    define_constructor(Constructor<Outer::Inner::GpuMat>()).
    define_constructor(Constructor<Outer::Inner::GpuMat, int, int, Outer::Inner::GpuMat::Allocator*>(),
      Arg("rows"), Arg("cols"), Arg("allocator") = static_cast<Outer::Inner::GpuMat::Allocator*>(Outer::Inner::GpuMat::defaultAllocator())).
    define_singleton_function("default_allocator", &Outer::Inner::GpuMat::defaultAllocator);

  Rice::Data_Type<Outer::Inner::GpuMat::Allocator> rb_cOuterInnerGpuMatAllocator = define_class_under<Outer::Inner::GpuMat::Allocator>(rb_cOuterInnerGpuMat, "Allocator").
    define_constructor(Constructor<Outer::Inner::GpuMat::Allocator>());

  Rice::Data_Type<Outer::Inner::GpuMatND> rb_cOuterInnerGpuMatND = define_class_under<Outer::Inner::GpuMatND>(rb_mOuterInner, "GpuMatND").
    define_constructor(Constructor<Outer::Inner::GpuMatND>()).
    define_constructor(Constructor<Outer::Inner::GpuMatND, Outer::Inner::GpuMatND::SizeArray, int>(),
      Arg("size"), Arg("type")).
    define_constructor(Constructor<Outer::Inner::GpuMatND, Outer::Inner::GpuMatND::SizeArray, int, void*, Outer::Inner::GpuMatND::StepArray>(),
      Arg("size"), Arg("type"), ArgBuffer("data"), Arg("step") = static_cast<Outer::Inner::GpuMatND::StepArray>(Outer::Inner::GpuMatND::defaultStepArray())).
    define_singleton_function("default_step_array", &Outer::Inner::GpuMatND::defaultStepArray);

  Rice::Data_Type<Outer::Inner::Stream> rb_cOuterInnerStream = define_class_under<Outer::Inner::Stream>(rb_mOuterInner, "Stream").
    define_constructor(Constructor<Outer::Inner::Stream>()).
    define_method("this_type_does_not_support_comparisons", &Outer::Inner::Stream::this_type_does_not_support_comparisons).
    define_method("to_i", [](const Outer::Inner::Stream& self) -> int
    {
      return self;
    });

  Rice::Data_Type<Outer::NonAssignable> rb_cOuterNonAssignable = define_class_under<Outer::NonAssignable>(rb_mOuter, "NonAssignable").
    define_constructor(Constructor<Outer::NonAssignable>());

  Rice::Data_Type<Outer::ProtectedAssign> rb_cOuterProtectedAssign = define_class_under<Outer::ProtectedAssign>(rb_mOuter, "ProtectedAssign").
    define_constructor(Constructor<Outer::ProtectedAssign>());

  Rice::Data_Type<Outer::AttributeTest> rb_cOuterAttributeTest = define_class_under<Outer::AttributeTest>(rb_mOuter, "AttributeTest").
    define_constructor(Constructor<Outer::AttributeTest>()).
    define_attr("regular_field", &Outer::AttributeTest::regular_field).
    define_attr("const_field", &Outer::AttributeTest::const_field, Rice::AttrAccess::Read).
    define_attr("non_assignable_field", &Outer::AttributeTest::non_assignable_field, Rice::AttrAccess::Read).
    define_attr("protected_assign_field", &Outer::AttributeTest::protected_assign_field, Rice::AttrAccess::Read);

  Rice::Data_Type<Outer::foo> rb_cOuterFoo = define_class_under<Outer::foo>(rb_mOuter, "Foo").
    define_constructor(Constructor<Outer::foo>()).
    define_attr("value", &Outer::foo::value);

  Module rb_mOuterFoobar = define_module_under(rb_mOuter, "Foobar");

  Rice::Data_Type<Outer::foobar::foo> rb_cOuterFoobarFoo = define_class_under<Outer::foobar::foo>(rb_mOuterFoobar, "Foo");

  Rice::Data_Type<Outer::foobar::wrapper<Outer::foobar::foo>> rb_cOuterFoobarWrapperFoo = define_class_under<Outer::foobar::wrapper<Outer::foobar::foo>>(rb_mOuterFoobar, "WrapperFoo").
    define_constructor(Constructor<Outer::foobar::wrapper<Outer::foobar::foo>>());
}