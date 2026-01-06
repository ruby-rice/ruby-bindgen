#include <template_inheritance.hpp>
#include "template_inheritance-rb.hpp"

using namespace Rice;

Rice::Class derived_ptrf;
Rice::Class rb_cBasePtrFloat;
Rice::Class rb_cBasePtrUnsignedChar;
Rice::Class rb_cDerivedPtrb;

template<typename Data_Type_T, typename T>
inline void BasePtr_builder(Data_Type_T& klass)
{
  klass.define_attr("data", &Tests::BasePtr<T>::data).
    define_constructor(Constructor<Tests::BasePtr<T>>()).
    define_constructor(Constructor<Tests::BasePtr<T>, T*>(),
      Arg("data_"));
};

template<typename Data_Type_T, typename T>
inline void DerivedPtr_builder(Data_Type_T& klass)
{
  klass.define_attr("step", &Tests::DerivedPtr<T>::step).
    define_constructor(Constructor<Tests::DerivedPtr<T>>()).
    define_constructor(Constructor<Tests::DerivedPtr<T>, T*, int>(),
      Arg("data_"), Arg("step_"));
};
void Init_TemplateInheritance()
{
  Module rb_mTests = define_module("Tests");
  
  rb_cBasePtrUnsignedChar = define_class_under<Tests::BasePtr<unsigned char>>(rb_mTests, "BasePtrUnsignedChar").
    define(&BasePtr_builder<Data_Type<Tests::BasePtr<unsigned char>>, unsigned char>);
  rb_cDerivedPtrb = define_class_under<Tests::DerivedPtr<unsigned char>, Tests::BasePtr<unsigned char>>(rb_mTests, "DerivedPtrb").
    define(&DerivedPtr_builder<Data_Type<Tests::DerivedPtr<unsigned char>>, unsigned char>);
  
  rb_cBasePtrFloat = define_class_under<Tests::BasePtr<float>>(rb_mTests, "BasePtrFloat").
    define(&BasePtr_builder<Data_Type<Tests::BasePtr<float>>, float>);
  derived_ptrf = define_class_under<Tests::DerivedPtr<float>, Tests::BasePtr<float>>(rb_mTests, "DerivedPtrf").
    define(&DerivedPtr_builder<Data_Type<Tests::DerivedPtr<float>>, float>);

}