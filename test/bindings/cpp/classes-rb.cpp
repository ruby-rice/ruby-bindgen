#include <classes.hpp>
#include "classes-rb.hpp"

using namespace Rice;

Rice::Class rb_cOuterBaseClass;
Rice::Class rb_cOuterFoo;
Rice::Class rb_cOuterFoobarWrapperFoo;
Rice::Class rb_cOuterInnerContainerClass;
Rice::Class rb_cOuterInnerContainerClassCallback;
Rice::Class rb_cOuterInnerContainerClassConfig;
Rice::Class rb_cOuterInnerGpuMat;
Rice::Class rb_cOuterInnerGpuMatAllocator;
Rice::Class rb_cOuterInnerGpuMatND;
Rice::Class rb_cOuterInnerStream;
Rice::Class rb_cOuterMyClass;
Rice::Class rb_cOuterRange;

template<typename Data_Type_T, typename T>
inline void SimpleVector_builder(Data_Type_T& klass)
{
  klass.define_attr("data", &Outer::SimpleVector<T>::data).
    define_attr("size", &Outer::SimpleVector<T>::size);
};

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

  rb_cOuterRange = define_class_under<Outer::Range>(rb_mOuter, "Range").
    define_constructor(Constructor<Outer::Range>()).
    define_attr("start", &Outer::Range::start).
    define_attr("end", &Outer::Range::end);

  rb_mOuter.define_constant("NAMESPACE_CONSTANT", Outer::NAMESPACE_CONSTANT);

  rb_mOuter.define_constant("NamespaceVariable", Outer::namespaceVariable);

  rb_cOuterBaseClass = define_class_under<Outer::BaseClass>(rb_mOuter, "BaseClass").
    define_constructor(Constructor<Outer::BaseClass>());

  rb_cOuterMyClass = define_class_under<Outer::MyClass, Outer::BaseClass>(rb_mOuter, "MyClass").
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

  rb_cOuterInnerContainerClass = define_class_under<Outer::Inner::ContainerClass>(rb_mOuterInner, "ContainerClass").
    define_constructor(Constructor<Outer::Inner::ContainerClass>()).
    define_attr("callback", &Outer::Inner::ContainerClass::callback).
    define_attr("config", &Outer::Inner::ContainerClass::config).
    define_attr("grid_type", &Outer::Inner::ContainerClass::gridType);

  rb_cOuterInnerContainerClassCallback = define_class_under<Outer::Inner::ContainerClass::Callback>(rb_cOuterInnerContainerClass, "Callback").
    define_constructor(Constructor<Outer::Inner::ContainerClass::Callback>()).
    define_method("compute?", &Outer::Inner::ContainerClass::Callback::compute);

  rb_cOuterInnerContainerClassConfig = define_class_under<Outer::Inner::ContainerClass::Config>(rb_cOuterInnerContainerClass, "Config").
    define_constructor(Constructor<Outer::Inner::ContainerClass::Config>()).
    define_attr("enable", &Outer::Inner::ContainerClass::Config::enable);

  Enum<Outer::Inner::ContainerClass::GridType> rb_cOuterInnerContainerClassGridType = define_enum_under<Outer::Inner::ContainerClass::GridType>("GridType", rb_cOuterInnerContainerClass).
    define_value("SYMMETRIC_GRID", Outer::Inner::ContainerClass::GridType::SYMMETRIC_GRID).
    define_value("ASYMMETRIC_GRID", Outer::Inner::ContainerClass::GridType::ASYMMETRIC_GRID);

  rb_cOuterInnerGpuMat = define_class_under<Outer::Inner::GpuMat>(rb_mOuterInner, "GpuMat").
    define_constructor(Constructor<Outer::Inner::GpuMat>()).
    define_constructor(Constructor<Outer::Inner::GpuMat, int, int, Outer::Inner::GpuMat::Allocator*>(),
      Arg("rows"), Arg("cols"), Arg("allocator") = static_cast<Outer::Inner::GpuMat::Allocator*>(Outer::Inner::GpuMat::defaultAllocator())).
    define_singleton_function("default_allocator", &Outer::Inner::GpuMat::defaultAllocator);

  rb_cOuterInnerGpuMatAllocator = define_class_under<Outer::Inner::GpuMat::Allocator>(rb_cOuterInnerGpuMat, "Allocator").
    define_constructor(Constructor<Outer::Inner::GpuMat::Allocator>());

  rb_cOuterInnerGpuMatND = define_class_under<Outer::Inner::GpuMatND>(rb_mOuterInner, "GpuMatND").
    define_constructor(Constructor<Outer::Inner::GpuMatND>()).
    define_constructor(Constructor<Outer::Inner::GpuMatND, Outer::Inner::GpuMatND::SizeArray, int>(),
      Arg("size"), Arg("type")).
    define_constructor(Constructor<Outer::Inner::GpuMatND, Outer::Inner::GpuMatND::SizeArray, int, void*, Outer::Inner::GpuMatND::StepArray>(),
      Arg("size"), Arg("type"), Arg("data"), Arg("step") = static_cast<Outer::Inner::GpuMatND::StepArray>(Outer::Inner::GpuMatND::defaultStepArray())).
    define_constructor(Constructor<Outer::Inner::GpuMatND, const Outer::SimpleVector<Outer::Range>&>(),
      Arg("ranges")).
    define_singleton_function("default_step_array", &Outer::Inner::GpuMatND::defaultStepArray);

  rb_cOuterInnerStream = define_class_under<Outer::Inner::Stream>(rb_mOuterInner, "Stream").
    define_constructor(Constructor<Outer::Inner::Stream>()).
    define_method("this_type_does_not_support_comparisons", &Outer::Inner::Stream::this_type_does_not_support_comparisons).
    define_method("to_i", [](const Outer::Inner::Stream& self) -> int
    {
      return self;
    });

  rb_cOuterFoo = define_class_under<Outer::foo>(rb_mOuter, "Foo").
    define_constructor(Constructor<Outer::foo>()).
    define_attr("value", &Outer::foo::value);

  Module rb_mOuterFoobar = define_module_under(rb_mOuter, "Foobar");

  rb_cOuterFoobarWrapperFoo = define_class_under<Outer::foobar::wrapper<Outer::foobar::foo>>(rb_mOuterFoobar, "WrapperFoo").
    define_constructor(Constructor<Outer::foobar::wrapper<Outer::foobar::foo>>());
}