#include <template_inheritance.hpp>
#include "template_inheritance-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T>
inline void BasePtr_builder(Data_Type_T& klass)
{
  klass.define_attr("data", &Tests::BasePtr<T>::data).
    define_constructor(Constructor<Tests::BasePtr<T>>()).
    define_constructor(Constructor<Tests::BasePtr<T>, T*>(),
      std::conditional_t<std::is_fundamental_v<T>, ArgBuffer, Arg>("data_"));
};

template<typename Data_Type_T, typename T>
inline void DerivedPtr_builder(Data_Type_T& klass)
{
  klass.define_attr("step", &Tests::DerivedPtr<T>::step).
    define_constructor(Constructor<Tests::DerivedPtr<T>>()).
    define_constructor(Constructor<Tests::DerivedPtr<T>, T*, int>(),
      std::conditional_t<std::is_fundamental_v<T>, ArgBuffer, Arg>("data_"), Arg("step_"));
};

template<typename Data_Type_T, typename P>
inline void WarperBase_builder(Data_Type_T& klass)
{
  klass.define_attr("projector", &Tests::WarperBase<P>::projector).
    define_method("set_projector", &Tests::WarperBase<P>::setProjector,
      Arg("p"));
};

template<typename Data_Type_T, typename _Tp, int m, int n>
inline void Matx_builder(Data_Type_T& klass)
{
  klass.define_constant("Rows", Tests::Matx<_Tp, m, n>::rows).
    define_constant("Cols", Tests::Matx<_Tp, m, n>::cols).
    define_constructor(Constructor<Tests::Matx<_Tp, m, n>>()).
    define_method("dot", &Tests::Matx<_Tp, m, n>::dot,
      Arg("other"));
};

template<typename Data_Type_T, typename _Tp, int cn>
inline void Vec_builder(Data_Type_T& klass)
{
  klass.define_constant("Channels", Tests::Vec<_Tp, cn>::channels).
    define_constructor(Constructor<Tests::Vec<_Tp, cn>>()).
    define_method("cross", &Tests::Vec<_Tp, cn>::cross,
      Arg("other"));
};

void Init_TemplateInheritance()
{
  Module rb_mTests = define_module("Tests");

  Rice::Data_Type<Tests::BasePtr<unsigned char>> rb_cBasePtrUnsignedChar = define_class_under<Tests::BasePtr<unsigned char>>(rb_mTests, "BasePtrUnsignedChar").
    define(&BasePtr_builder<Data_Type<Tests::BasePtr<unsigned char>>, unsigned char>);
  Rice::Data_Type<Tests::DerivedPtr<unsigned char>> rb_cDerivedPtrb = define_class_under<Tests::DerivedPtr<unsigned char>, Tests::BasePtr<unsigned char>>(rb_mTests, "DerivedPtrb").
    define(&DerivedPtr_builder<Data_Type<Tests::DerivedPtr<unsigned char>>, unsigned char>);

  Rice::Data_Type<Tests::BasePtr<float>> rb_cBasePtrFloat = define_class_under<Tests::BasePtr<float>>(rb_mTests, "BasePtrFloat").
    define(&BasePtr_builder<Data_Type<Tests::BasePtr<float>>, float>);
  Rice::Data_Type<Tests::DerivedPtr<float>> derived_ptrf = define_class_under<Tests::DerivedPtr<float>, Tests::BasePtr<float>>(rb_mTests, "DerivedPtrf").
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

  Rice::Data_Type<Tests::Matx<unsigned char, 2, 1>> rb_cMatxUnsignedChar21 = define_class_under<Tests::Matx<unsigned char, 2, 1>>(rb_mTests, "MatxUnsignedChar21").
    define(&Matx_builder<Data_Type<Tests::Matx<unsigned char, 2, 1>>, unsigned char, 2, 1>);
  Rice::Data_Type<Tests::Vec<unsigned char, 2>> rb_cVec2b = define_class_under<Tests::Vec<unsigned char, 2>, Tests::Matx<unsigned char, 2, 1>>(rb_mTests, "Vec2b").
    define(&Vec_builder<Data_Type<Tests::Vec<unsigned char, 2>>, unsigned char, 2>);

  Rice::Data_Type<Tests::Matx<int, 3, 1>> rb_cMatxInt31 = define_class_under<Tests::Matx<int, 3, 1>>(rb_mTests, "MatxInt31").
    define(&Matx_builder<Data_Type<Tests::Matx<int, 3, 1>>, int, 3, 1>);
  Rice::Data_Type<Tests::Vec<int, 3>> rb_cVec3i = define_class_under<Tests::Vec<int, 3>, Tests::Matx<int, 3, 1>>(rb_mTests, "Vec3i").
    define(&Vec_builder<Data_Type<Tests::Vec<int, 3>>, int, 3>);

  Rice::Data_Type<Tests::Matx<double, 4, 1>> rb_cMatxDouble41 = define_class_under<Tests::Matx<double, 4, 1>>(rb_mTests, "MatxDouble41").
    define(&Matx_builder<Data_Type<Tests::Matx<double, 4, 1>>, double, 4, 1>);
  Rice::Data_Type<Tests::Vec<double, 4>> rb_cVec4d = define_class_under<Tests::Vec<double, 4>, Tests::Matx<double, 4, 1>>(rb_mTests, "Vec4d").
    define(&Vec_builder<Data_Type<Tests::Vec<double, 4>>, double, 4>);
}