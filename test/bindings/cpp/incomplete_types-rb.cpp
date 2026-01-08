#include <incomplete_types.hpp>
#include "incomplete_types-rb.hpp"

using namespace Rice;

Rice::Class rb_cOuterInnerPimplClass;
Rice::Class rb_cOuterInnerPimplClassWithConstructor;
Rice::Class rb_cOuterInnerPimplClassWithPublicField;
Rice::Class rb_cOuterInnerPimplClassWithSmartPtr;
Rice::Class rb_cOuterInnerPimplClassWithStaticFields;
Rice::Class rb_cOuterInnerPimplClassWithStaticMethods;

template<typename Data_Type_T, typename T>
inline void Ptr_builder(Data_Type_T& klass)
{
  klass.define_attr("ptr", &Outer::Inner::Ptr<T>::ptr);
};
void Init_IncompleteTypes()
{
  Module rb_mOuter = define_module("Outer");
  
  Module rb_mOuterInner = define_module_under(rb_mOuter, "Inner");
  
  rb_cOuterInnerPimplClass = define_class_under<Outer::Inner::PimplClass>(rb_mOuterInner, "PimplClass").
    define_constructor(Constructor<Outer::Inner::PimplClass>()).
    define_method("empty?", &Outer::Inner::PimplClass::empty);
  
  
  rb_cOuterInnerPimplClassWithPublicField = define_class_under<Outer::Inner::PimplClassWithPublicField>(rb_mOuterInner, "PimplClassWithPublicField").
    define_constructor(Constructor<Outer::Inner::PimplClassWithPublicField>()).
    define_attr("value", &Outer::Inner::PimplClassWithPublicField::value);
  
  
  rb_cOuterInnerPimplClassWithConstructor = define_class_under<Outer::Inner::PimplClassWithConstructor>(rb_mOuterInner, "PimplClassWithConstructor").
    define_constructor(Constructor<Outer::Inner::PimplClassWithConstructor, int>(),
      Arg("value")).
    define_constructor(Constructor<Outer::Inner::PimplClassWithConstructor>()).
    define_method("get_value", &Outer::Inner::PimplClassWithConstructor::getValue);
  
  
  rb_cOuterInnerPimplClassWithSmartPtr = define_class_under<Outer::Inner::PimplClassWithSmartPtr>(rb_mOuterInner, "PimplClassWithSmartPtr").
    define_constructor(Constructor<Outer::Inner::PimplClassWithSmartPtr>()).
    define_attr("data", &Outer::Inner::PimplClassWithSmartPtr::data).
    define_attr("value", &Outer::Inner::PimplClassWithSmartPtr::value);
  
  
  rb_cOuterInnerPimplClassWithStaticFields = define_class_under<Outer::Inner::PimplClassWithStaticFields>(rb_mOuterInner, "PimplClassWithStaticFields").
    define_constructor(Constructor<Outer::Inner::PimplClassWithStaticFields>()).
    define_singleton_attr("StaticValue", &Outer::Inner::PimplClassWithStaticFields::staticValue).
    define_singleton_attr("StaticData", &Outer::Inner::PimplClassWithStaticFields::staticData);
  
  
  rb_cOuterInnerPimplClassWithStaticMethods = define_class_under<Outer::Inner::PimplClassWithStaticMethods>(rb_mOuterInner, "PimplClassWithStaticMethods").
    define_constructor(Constructor<Outer::Inner::PimplClassWithStaticMethods>()).
    define_singleton_function("get_value", &Outer::Inner::PimplClassWithStaticMethods::getValue).
    define_singleton_function("set_value", &Outer::Inner::PimplClassWithStaticMethods::setValue,
      Arg("val"));
  

}