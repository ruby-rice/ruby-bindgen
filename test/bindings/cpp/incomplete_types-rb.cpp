#include <incomplete_types.hpp>
#include "incomplete_types-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T>
inline void Ptr_builder(Data_Type_T& klass)
{
  klass.define_attr("ptr", &Outer::Inner::Ptr<T>::ptr);
};

void Init_IncompleteTypes()
{
  Module rb_mOuter = define_module("Outer");

  Module rb_mOuterInner = define_module_under(rb_mOuter, "Inner");

  Rice::Data_Type<Outer::Inner::PimplClass> rb_cOuterInnerPimplClass = define_class_under<Outer::Inner::PimplClass>(rb_mOuterInner, "PimplClass");

 

  Rice::Data_Type<Outer::Inner::PimplClass::Impl> rb_cOuterInnerPimplClassImpl = define_class_under<Outer::Inner::PimplClass::Impl>(rb_cOuterInnerPimplClass, "Impl");

  rb_cOuterInnerPimplClass.
    define_constructor(Constructor<Outer::Inner::PimplClass>()).
    define_method("get_impl", &Outer::Inner::PimplClass::getImpl).
    define_method("empty?", &Outer::Inner::PimplClass::empty);

  Rice::Data_Type<Outer::Inner::PimplClassWithPublicField> rb_cOuterInnerPimplClassWithPublicField = define_class_under<Outer::Inner::PimplClassWithPublicField>(rb_mOuterInner, "PimplClassWithPublicField");

 

  Rice::Data_Type<Outer::Inner::PimplClassWithPublicField::Impl> rb_cOuterInnerPimplClassWithPublicFieldImpl = define_class_under<Outer::Inner::PimplClassWithPublicField::Impl>(rb_cOuterInnerPimplClassWithPublicField, "Impl");

  rb_cOuterInnerPimplClassWithPublicField.
    define_constructor(Constructor<Outer::Inner::PimplClassWithPublicField>()).
    define_attr("impl", &Outer::Inner::PimplClassWithPublicField::impl).
    define_attr("value", &Outer::Inner::PimplClassWithPublicField::value);

  Rice::Data_Type<Outer::Inner::PimplClassWithConstructor> rb_cOuterInnerPimplClassWithConstructor = define_class_under<Outer::Inner::PimplClassWithConstructor>(rb_mOuterInner, "PimplClassWithConstructor");

 

  Rice::Data_Type<Outer::Inner::PimplClassWithConstructor::Impl> rb_cOuterInnerPimplClassWithConstructorImpl = define_class_under<Outer::Inner::PimplClassWithConstructor::Impl>(rb_cOuterInnerPimplClassWithConstructor, "Impl");

  rb_cOuterInnerPimplClassWithConstructor.
    define_constructor(Constructor<Outer::Inner::PimplClassWithConstructor, Outer::Inner::PimplClassWithConstructor::Impl*, int>(),
      Arg("impl"), Arg("offset")).
    define_constructor(Constructor<Outer::Inner::PimplClassWithConstructor, int>(),
      Arg("value")).
    define_constructor(Constructor<Outer::Inner::PimplClassWithConstructor>()).
    define_method("get_value", &Outer::Inner::PimplClassWithConstructor::getValue);

  Rice::Data_Type<Outer::Inner::PimplClassWithSmartPtr> rb_cOuterInnerPimplClassWithSmartPtr = define_class_under<Outer::Inner::PimplClassWithSmartPtr>(rb_mOuterInner, "PimplClassWithSmartPtr");

 

  Rice::Data_Type<Outer::Inner::PimplClassWithSmartPtr::Impl> rb_cOuterInnerPimplClassWithSmartPtrImpl = define_class_under<Outer::Inner::PimplClassWithSmartPtr::Impl>(rb_cOuterInnerPimplClassWithSmartPtr, "Impl");

  rb_cOuterInnerPimplClassWithSmartPtr.
    define_constructor(Constructor<Outer::Inner::PimplClassWithSmartPtr>()).
    define_attr("impl", &Outer::Inner::PimplClassWithSmartPtr::impl).
    define_attr("data", &Outer::Inner::PimplClassWithSmartPtr::data).
    define_attr("value", &Outer::Inner::PimplClassWithSmartPtr::value);

  Rice::Data_Type<Outer::Inner::PimplClassWithDoublePtr> rb_cOuterInnerPimplClassWithDoublePtr = define_class_under<Outer::Inner::PimplClassWithDoublePtr>(rb_mOuterInner, "PimplClassWithDoublePtr");

 

  Rice::Data_Type<Outer::Inner::PimplClassWithDoublePtr::Impl> rb_cOuterInnerPimplClassWithDoublePtrImpl = define_class_under<Outer::Inner::PimplClassWithDoublePtr::Impl>(rb_cOuterInnerPimplClassWithDoublePtr, "Impl");

  rb_cOuterInnerPimplClassWithDoublePtr.
    define_constructor(Constructor<Outer::Inner::PimplClassWithDoublePtr>()).
    define_attr("pp_impl", &Outer::Inner::PimplClassWithDoublePtr::ppImpl).
    define_attr("ppp_impl", &Outer::Inner::PimplClassWithDoublePtr::pppImpl).
    define_attr("pp_value", &Outer::Inner::PimplClassWithDoublePtr::ppValue).
    define_attr("value", &Outer::Inner::PimplClassWithDoublePtr::value);

  Rice::Data_Type<Outer::Inner::PimplClassWithStaticFields> rb_cOuterInnerPimplClassWithStaticFields = define_class_under<Outer::Inner::PimplClassWithStaticFields>(rb_mOuterInner, "PimplClassWithStaticFields");

 

  Rice::Data_Type<Outer::Inner::PimplClassWithStaticFields::Impl> rb_cOuterInnerPimplClassWithStaticFieldsImpl = define_class_under<Outer::Inner::PimplClassWithStaticFields::Impl>(rb_cOuterInnerPimplClassWithStaticFields, "Impl");

  rb_cOuterInnerPimplClassWithStaticFields.
    define_constructor(Constructor<Outer::Inner::PimplClassWithStaticFields>()).
    define_singleton_attr("StaticImplPtr", &Outer::Inner::PimplClassWithStaticFields::staticImplPtr).
    define_singleton_attr("StaticSmartPtr", &Outer::Inner::PimplClassWithStaticFields::staticSmartPtr).
    define_singleton_attr("StaticValue", &Outer::Inner::PimplClassWithStaticFields::staticValue).
    define_singleton_attr("StaticData", &Outer::Inner::PimplClassWithStaticFields::staticData);

  Rice::Data_Type<Outer::Inner::PimplClassWithStaticMethods> rb_cOuterInnerPimplClassWithStaticMethods = define_class_under<Outer::Inner::PimplClassWithStaticMethods>(rb_mOuterInner, "PimplClassWithStaticMethods");

 

  Rice::Data_Type<Outer::Inner::PimplClassWithStaticMethods::Impl> rb_cOuterInnerPimplClassWithStaticMethodsImpl = define_class_under<Outer::Inner::PimplClassWithStaticMethods::Impl>(rb_cOuterInnerPimplClassWithStaticMethods, "Impl");

  rb_cOuterInnerPimplClassWithStaticMethods.
    define_constructor(Constructor<Outer::Inner::PimplClassWithStaticMethods>()).
    define_singleton_function("create_impl", &Outer::Inner::PimplClassWithStaticMethods::createImpl).
    define_singleton_function("init_from_impl", &Outer::Inner::PimplClassWithStaticMethods::initFromImpl,
      Arg("impl")).
    define_singleton_function("get_smart_impl", &Outer::Inner::PimplClassWithStaticMethods::getSmartImpl).
    define_singleton_function("get_value", &Outer::Inner::PimplClassWithStaticMethods::getValue).
    define_singleton_function("set_value", &Outer::Inner::PimplClassWithStaticMethods::setValue,
      Arg("val"));

  Rice::Data_Type<Outer::Inner::FactoryClass> rb_cOuterInnerFactoryClass = define_class_under<Outer::Inner::FactoryClass>(rb_mOuterInner, "FactoryClass").
    define_constructor(Constructor<Outer::Inner::FactoryClass>()).
    define_method("clone", &Outer::Inner::FactoryClass::clone).
    define_attr("parent", &Outer::Inner::FactoryClass::parent).
    define_method("set_parent", &Outer::Inner::FactoryClass::setParent,
      Arg("p")).
    define_method("get_value", &Outer::Inner::FactoryClass::getValue).
    define_singleton_function("create", &Outer::Inner::FactoryClass::create);

  Rice::Data_Type<Outer::Inner::OuterWithFactory> rb_cOuterInnerOuterWithFactory = define_class_under<Outer::Inner::OuterWithFactory>(rb_mOuterInner, "OuterWithFactory").
    define_constructor(Constructor<Outer::Inner::OuterWithFactory>()).
    define_attr("data", &Outer::Inner::OuterWithFactory::data);

  Rice::Data_Type<Outer::Inner::OuterWithFactory::InnerFactory> rb_cOuterInnerOuterWithFactoryInnerFactory = define_class_under<Outer::Inner::OuterWithFactory::InnerFactory>(rb_cOuterInnerOuterWithFactory, "InnerFactory").
    define_constructor(Constructor<Outer::Inner::OuterWithFactory::InnerFactory>()).
    define_singleton_function("create_outer", &Outer::Inner::OuterWithFactory::InnerFactory::createOuter);

  Rice::Data_Type<Outer::Inner::TypedefReturnClass> rb_cOuterInnerTypedefReturnClass = define_class_under<Outer::Inner::TypedefReturnClass>(rb_mOuterInner, "TypedefReturnClass").
    define_constructor(Constructor<Outer::Inner::TypedefReturnClass>()).
    define_method("get_count", &Outer::Inner::TypedefReturnClass::getCount).
    define_method("get_signed_count", &Outer::Inner::TypedefReturnClass::getSignedCount).
    define_method("get_size", &Outer::Inner::TypedefReturnClass::getSize).
    define_method("reset", &Outer::Inner::TypedefReturnClass::reset).
    define_attr("count", &Outer::Inner::TypedefReturnClass::count).
    define_attr("signed_count", &Outer::Inner::TypedefReturnClass::signedCount).
    define_attr("sz", &Outer::Inner::TypedefReturnClass::sz);

  Rice::Data_Type<Outer::Inner::PimplClassWithRefReturn> rb_cOuterInnerPimplClassWithRefReturn = define_class_under<Outer::Inner::PimplClassWithRefReturn>(rb_mOuterInner, "PimplClassWithRefReturn");

 

  Rice::Data_Type<Outer::Inner::PimplClassWithRefReturn::Impl> rb_cOuterInnerPimplClassWithRefReturnImpl = define_class_under<Outer::Inner::PimplClassWithRefReturn::Impl>(rb_cOuterInnerPimplClassWithRefReturn, "Impl");

  rb_cOuterInnerPimplClassWithRefReturn.
    define_constructor(Constructor<Outer::Inner::PimplClassWithRefReturn>()).
    define_method("get_impl_ref", &Outer::Inner::PimplClassWithRefReturn::getImplRef).
    define_method("get_impl_const_ref", &Outer::Inner::PimplClassWithRefReturn::getImplConstRef).
    define_method("get_impl_rvalue_ref", &Outer::Inner::PimplClassWithRefReturn::getImplRvalueRef).
    define_method("get_value_ref", &Outer::Inner::PimplClassWithRefReturn::getValueRef).
    define_method("get_value_const_ref", &Outer::Inner::PimplClassWithRefReturn::getValueConstRef).
    define_method("get_value", &Outer::Inner::PimplClassWithRefReturn::getValue);
}