#include <template_inheritance.hpp>
#include "template_inheritance-rb.hpp"

using namespace Rice;

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

template<typename Data_Type_T, typename P>
inline void WarperBase_builder(Data_Type_T& klass)
{
  klass.define_attr("projector", &Tests::WarperBase<P>::projector).
    define_method("set_projector", &Tests::WarperBase<P>::setProjector,
      Arg("p"));
};

void Init_TemplateInheritance()
{
  Module rb_mTests = define_module("Tests");

  Rice::Data_Type<Tests::BasePtr<unsigned char>> rb_cBasePtrUnsignedChar = define_class_under<Tests::BasePtr<unsigned char>>(rb_mTests, "BasePtrUnsignedChar").
    define(&BasePtr_builder<Data_Type<Tests::BasePtr<unsigned char>>, unsigned char>);
  Rice::Data_Type<Tests::DerivedPtr<unsigned char>> rb_cDerivedPtrb = define_class_under<Tests::DerivedPtr<unsigned char>, Tests::BasePtr<unsigned char>>(rb_mTests, "DerivedPtrUnsignedChar").
    define(&DerivedPtr_builder<Data_Type<Tests::DerivedPtr<unsigned char>>, unsigned char>);

  Rice::Data_Type<Tests::BasePtr<float>> rb_cBasePtrFloat = define_class_under<Tests::BasePtr<float>>(rb_mTests, "BasePtrFloat").
    define(&BasePtr_builder<Data_Type<Tests::BasePtr<float>>, float>);
  Rice::Data_Type<Tests::DerivedPtr<float>> derived_ptrf = define_class_under<Tests::DerivedPtr<float>, Tests::BasePtr<float>>(rb_mTests, "DerivedPtrFloat").
    define(&DerivedPtr_builder<Data_Type<Tests::DerivedPtr<float>>, float>);

  Rice::Data_Type<Tests::PlaneProjector> rb_cTestsPlaneProjector = define_class_under<Tests::PlaneProjector>(rb_mTests, "PlaneProjector").
    define_attr("scale", &Tests::PlaneProjector::scale).
    define_constructor(Constructor<Tests::PlaneProjector>());

  Rice::Data_Type<Tests::WarperBase<Tests::PlaneProjector>> rb_cWarperBasePlaneProjector = define_class_under<Tests::WarperBase<Tests::PlaneProjector>>(rb_mTests, "WarperBasePlaneProjector").
    define(&WarperBase_builder<Data_Type<Tests::WarperBase<Tests::PlaneProjector>>, Tests::PlaneProjector>);
  Rice::Data_Type<Tests::PlaneWarper> rb_cTestsPlaneWarper = define_class_under<Tests::PlaneWarper, Tests::WarperBase<Tests::PlaneProjector>>(rb_mTests, "PlaneWarper").
    define_constructor(Constructor<Tests::PlaneWarper, float>(),
      Arg("scale") = static_cast<float>(1.0f)).
    define_method("get_scale", &Tests::PlaneWarper::getScale);
}