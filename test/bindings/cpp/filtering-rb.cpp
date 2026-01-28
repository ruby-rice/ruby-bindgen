#include <filtering.hpp>
#include "filtering-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T>
inline void UsesSkippedType_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Outer::UsesSkippedType<T>>()).
    define_method("normal_method", &Outer::UsesSkippedType<T>::normalMethod);
};

void Init_Filtering()
{
  Module rb_mOuter = define_module("Outer");

  rb_mOuter.define_module_function("exported_function", &Outer::exportedFunction);

  rb_mOuter.define_module_function("normal_function", &Outer::normalFunction);

  rb_mOuter.define_module_function<void(*)(const char*)>("print_formatted", &Outer::printFormatted,
    Arg("msg"));

  Rice::Data_Type<Outer::MyClass> rb_cOuterMyClass = define_class_under<Outer::MyClass>(rb_mOuter, "MyClass").
    define_constructor(Constructor<Outer::MyClass>()).
    define_method("new_method", &Outer::MyClass::newMethod);

  Rice::Data_Type<Outer::ClassWithDeprecatedConstructor> rb_cOuterClassWithDeprecatedConstructor = define_class_under<Outer::ClassWithDeprecatedConstructor>(rb_mOuter, "ClassWithDeprecatedConstructor").
    define_constructor(Constructor<Outer::ClassWithDeprecatedConstructor, int, int>(),
      Arg("param1"), Arg("param2")).
    define_method("do_something", &Outer::ClassWithDeprecatedConstructor::doSomething);

  Rice::Data_Type<Outer::UsesSkippedType<int>> rb_cUsesSkippedTypeInt = define_class_under<Outer::UsesSkippedType<int>>(rb_mOuter, "UsesSkippedTypeInt").
    define(&UsesSkippedType_builder<Data_Type<Outer::UsesSkippedType<int>>, int>);

  Rice::Data_Type<Outer::DeprecatedTemplate<int>> rb_cDeprecatedTemplateInt = define_class_under<Outer::DeprecatedTemplate<int>>(rb_mOuter, "DeprecatedTemplateInt");

  Rice::Data_Type<Outer::OtherClass> rb_cOuterOtherClass = define_class_under<Outer::OtherClass>(rb_mOuter, "OtherClass").
    define_constructor(Constructor<Outer::OtherClass>());

  Rice::Data_Type<Outer::ClassWithDeprecatedConversion> rb_cOuterClassWithDeprecatedConversion = define_class_under<Outer::ClassWithDeprecatedConversion>(rb_mOuter, "ClassWithDeprecatedConversion").
    define_constructor(Constructor<Outer::ClassWithDeprecatedConversion>()).
    define_method("to_i", [](const Outer::ClassWithDeprecatedConversion& self) -> int
    {
      return self;
    });
}