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
    template define_method<void(Tests::WarperBase<P>::*)(const P&)>("set_projector", &Tests::WarperBase<P>::setProjector,
      Arg("p"));
};

template<typename Data_Type_T, typename _Tp, int m, int n>
inline void Matx_builder(Data_Type_T& klass)
{
  klass.define_constant("Rows", Tests::Matx<_Tp, m, n>::rows).
    define_constant("Cols", Tests::Matx<_Tp, m, n>::cols).
    define_attr("val", &Tests::Matx<_Tp, m, n>::val, Rice::AttrAccess::Read).
    define_constructor(Constructor<Tests::Matx<_Tp, m, n>>()).
    template define_method<_Tp(Tests::Matx<_Tp, m, n>::*)(const Tests::Matx<_Tp, m, n>&) const>("dot", &Tests::Matx<_Tp, m, n>::dot,
      Arg("other"));
};

template<typename Data_Type_T, typename _Tp, int cn>
inline void Vec_builder(Data_Type_T& klass)
{
  klass.define_constant("Channels", Tests::Vec<_Tp, cn>::channels).
    define_constructor(Constructor<Tests::Vec<_Tp, cn>>()).
    template define_method<_Tp(Tests::Vec<_Tp, cn>::*)(const Tests::Vec<_Tp, cn>&) const>("cross", &Tests::Vec<_Tp, cn>::cross,
      Arg("other"));
};

template<typename Data_Type_T, typename _Tp>
inline void Mat__builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Tests::Mat_<_Tp>>()).
    define_constructor(Constructor<Tests::Mat_<_Tp>, int, int>(),
      Arg("rows_"), Arg("cols_")).
    template define_method<_Tp&(Tests::Mat_<_Tp>::*)(int, int)>("at", &Tests::Mat_<_Tp>::at,
      Arg("row"), Arg("col"));
};

