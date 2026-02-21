#include <incomplete_types.hpp>
#include "incomplete_types-rb.hpp"

using namespace Rice;

#include "incomplete_types-rb.ipp"

void Init_IncompleteTypes()
{
  Rice::Data_Type<ExternalOpaqueA> rb_cExternalOpaqueA = define_class<ExternalOpaqueA>("ExternalOpaqueA");

  Rice::Data_Type<ExternalOpaqueB> rb_cExternalOpaqueB = define_class<ExternalOpaqueB>("ExternalOpaqueB");

  Rice::Data_Type<OpaqueTypeC> rb_cOpaqueTypeC = define_class<OpaqueTypeC>("OpaqueTypeC");

  Rice::Data_Type<OpaqueTypeD> rb_cOpaqueTypeD = define_class<OpaqueTypeD>("OpaqueTypeD");

  Module rb_mOuter = define_module("Outer");

  Module rb_mOuterInner = define_module_under(rb_mOuter, "Inner");

  Rice::Data_Type<Outer::Inner::PimplClass> rb_cOuterInnerPimplClass = define_class_under<Outer::Inner::PimplClass>(rb_mOuterInner, "PimplClass");

  Rice::Data_Type<Outer::Inner::PimplClass::Impl> rb_cOuterInnerPimplClassImpl = define_class_under<Outer::Inner::PimplClass::Impl>(rb_cOuterInnerPimplClass, "Impl");

  rb_cOuterInnerPimplClass.
    define_constructor(Constructor<Outer::Inner::PimplClass>()).
    define_method<Outer::Inner::PimplClass::Impl*(Outer::Inner::PimplClass::*)() const>("get_impl", &Outer::Inner::PimplClass::getImpl).
    define_method<bool(Outer::Inner::PimplClass::*)() const>("empty?", &Outer::Inner::PimplClass::empty);

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
    define_method<int(Outer::Inner::PimplClassWithConstructor::*)() const>("get_value", &Outer::Inner::PimplClassWithConstructor::getValue);

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
    define_singleton_function<Outer::Inner::PimplClassWithStaticMethods::Impl*(*)()>("create_impl", &Outer::Inner::PimplClassWithStaticMethods::createImpl).
    define_singleton_function<void(*)(Outer::Inner::PimplClassWithStaticMethods::Impl*)>("init_from_impl", &Outer::Inner::PimplClassWithStaticMethods::initFromImpl,
      Arg("impl")).
    define_singleton_function<Outer::Inner::Ptr<Outer::Inner::PimplClassWithStaticMethods::Impl>(*)()>("get_smart_impl", &Outer::Inner::PimplClassWithStaticMethods::getSmartImpl).
    define_singleton_function<int(*)()>("get_value", &Outer::Inner::PimplClassWithStaticMethods::getValue).
    define_singleton_function<void(*)(int)>("set_value", &Outer::Inner::PimplClassWithStaticMethods::setValue,
      Arg("val"));

  Rice::Data_Type<Outer::Inner::Ptr<Outer::Inner::FactoryClass>> rb_cOuterInnerPtrOuterInnerFactoryclass = Ptr_instantiate<Outer::Inner::FactoryClass>(rb_mOuterInner, "PtrOuterInnerFactoryclass");

  Rice::Data_Type<Outer::Inner::FactoryClass> rb_cOuterInnerFactoryClass = define_class_under<Outer::Inner::FactoryClass>(rb_mOuterInner, "FactoryClass").
    define_constructor(Constructor<Outer::Inner::FactoryClass>()).
    define_singleton_function<Outer::Inner::Ptr<Outer::Inner::FactoryClass>(*)()>("create", &Outer::Inner::FactoryClass::create).
    define_method<Outer::Inner::Ptr<Outer::Inner::FactoryClass>(Outer::Inner::FactoryClass::*)() const>("clone", &Outer::Inner::FactoryClass::clone).
    define_attr("parent", &Outer::Inner::FactoryClass::parent).
    define_method<void(Outer::Inner::FactoryClass::*)(Outer::Inner::Ptr<Outer::Inner::FactoryClass>)>("set_parent", &Outer::Inner::FactoryClass::setParent,
      Arg("p")).
    define_method<int(Outer::Inner::FactoryClass::*)() const>("get_value", &Outer::Inner::FactoryClass::getValue);

  Rice::Data_Type<Outer::Inner::OuterWithFactory> rb_cOuterInnerOuterWithFactory = define_class_under<Outer::Inner::OuterWithFactory>(rb_mOuterInner, "OuterWithFactory").
    define_constructor(Constructor<Outer::Inner::OuterWithFactory>()).
    define_attr("data", &Outer::Inner::OuterWithFactory::data);

  Rice::Data_Type<Outer::Inner::OuterWithFactory::InnerFactory> rb_cOuterInnerOuterWithFactoryInnerFactory = define_class_under<Outer::Inner::OuterWithFactory::InnerFactory>(rb_cOuterInnerOuterWithFactory, "InnerFactory").
    define_constructor(Constructor<Outer::Inner::OuterWithFactory::InnerFactory>()).
    define_singleton_function<Outer::Inner::Ptr<Outer::Inner::OuterWithFactory>(*)()>("create_outer", &Outer::Inner::OuterWithFactory::InnerFactory::createOuter);

  Rice::Data_Type<Outer::Inner::TypedefReturnClass> rb_cOuterInnerTypedefReturnClass = define_class_under<Outer::Inner::TypedefReturnClass>(rb_mOuterInner, "TypedefReturnClass").
    define_constructor(Constructor<Outer::Inner::TypedefReturnClass>()).
    define_method<uint64_t(Outer::Inner::TypedefReturnClass::*)() const>("get_count", &Outer::Inner::TypedefReturnClass::getCount).
    define_method<int64_t(Outer::Inner::TypedefReturnClass::*)() const>("get_signed_count", &Outer::Inner::TypedefReturnClass::getSignedCount).
    define_method<std::size_t(Outer::Inner::TypedefReturnClass::*)() const>("get_size", &Outer::Inner::TypedefReturnClass::getSize).
    define_method<void(Outer::Inner::TypedefReturnClass::*)()>("reset", &Outer::Inner::TypedefReturnClass::reset).
    define_attr("count", &Outer::Inner::TypedefReturnClass::count).
    define_attr("signed_count", &Outer::Inner::TypedefReturnClass::signedCount).
    define_attr("sz", &Outer::Inner::TypedefReturnClass::sz);

  Rice::Data_Type<Outer::Inner::PimplClassWithRefReturn> rb_cOuterInnerPimplClassWithRefReturn = define_class_under<Outer::Inner::PimplClassWithRefReturn>(rb_mOuterInner, "PimplClassWithRefReturn");

  Rice::Data_Type<Outer::Inner::PimplClassWithRefReturn::Impl> rb_cOuterInnerPimplClassWithRefReturnImpl = define_class_under<Outer::Inner::PimplClassWithRefReturn::Impl>(rb_cOuterInnerPimplClassWithRefReturn, "Impl");

  rb_cOuterInnerPimplClassWithRefReturn.
    define_constructor(Constructor<Outer::Inner::PimplClassWithRefReturn>()).
    define_method<Outer::Inner::PimplClassWithRefReturn::Impl&(Outer::Inner::PimplClassWithRefReturn::*)()>("get_impl_ref", &Outer::Inner::PimplClassWithRefReturn::getImplRef).
    define_method<const Outer::Inner::PimplClassWithRefReturn::Impl&(Outer::Inner::PimplClassWithRefReturn::*)() const>("get_impl_const_ref", &Outer::Inner::PimplClassWithRefReturn::getImplConstRef).
    define_method<Outer::Inner::PimplClassWithRefReturn::Impl&&(Outer::Inner::PimplClassWithRefReturn::*)()>("get_impl_rvalue_ref", &Outer::Inner::PimplClassWithRefReturn::getImplRvalueRef).
    define_method<int&(Outer::Inner::PimplClassWithRefReturn::*)()>("get_value_ref", &Outer::Inner::PimplClassWithRefReturn::getValueRef).
    define_method<const int&(Outer::Inner::PimplClassWithRefReturn::*)() const>("get_value_const_ref", &Outer::Inner::PimplClassWithRefReturn::getValueConstRef).
    define_method<int(Outer::Inner::PimplClassWithRefReturn::*)() const>("get_value", &Outer::Inner::PimplClassWithRefReturn::getValue);

  Rice::Data_Type<Outer::Inner::ExternalOpaqueWrapper> rb_cOuterInnerExternalOpaqueWrapper = define_class_under<Outer::Inner::ExternalOpaqueWrapper>(rb_mOuterInner, "ExternalOpaqueWrapper").
    define_constructor(Constructor<Outer::Inner::ExternalOpaqueWrapper>()).
    define_singleton_function<OpaqueHandleA(*)()>("get_handle_a", &Outer::Inner::ExternalOpaqueWrapper::getHandleA).
    define_singleton_function<OpaqueHandleB(*)()>("get_handle_b", &Outer::Inner::ExternalOpaqueWrapper::getHandleB).
    define_singleton_function<void(*)(OpaqueHandleA)>("use_handle_a", &Outer::Inner::ExternalOpaqueWrapper::useHandleA,
      Arg("handle")).
    define_singleton_function<void(*)(OpaqueHandleB)>("use_handle_b", &Outer::Inner::ExternalOpaqueWrapper::useHandleB,
      Arg("handle")).
    define_singleton_function<ExternalOpaqueA*(*)()>("get_raw_a", &Outer::Inner::ExternalOpaqueWrapper::getRawA).
    define_singleton_function<ExternalOpaqueB*(*)()>("get_raw_b", &Outer::Inner::ExternalOpaqueWrapper::getRawB);

  Rice::Data_Type<Outer::Inner::DeleterUser> rb_cOuterInnerDeleterUser = define_class_under<Outer::Inner::DeleterUser>(rb_mOuterInner, "DeleterUser").
    define_constructor(Constructor<Outer::Inner::DeleterUser>()).
    define_attr("deleter_a", &Outer::Inner::DeleterUser::deleterA).
    define_method<Outer::Inner::Deleter<ExternalOpaqueB>(Outer::Inner::DeleterUser::*)()>("get_deleter_b", &Outer::Inner::DeleterUser::getDeleterB);

}
