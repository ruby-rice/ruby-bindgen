template<typename T>
inline Rice::Data_Type<Tests::BasePtr<T>> BasePtr_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Tests::BasePtr<T>>(parent, name).
    define_attr("data", &Tests::BasePtr<T>::data).
    define_constructor(Constructor<Tests::BasePtr<T>>()).
    define_constructor(Constructor<Tests::BasePtr<T>, T*>(),
      std::conditional_t<std::is_fundamental_v<T>, ArgBuffer, Arg>("data_"));
}

template<typename T>
inline Rice::Data_Type<Tests::DerivedPtr<T>> DerivedPtr_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Tests::DerivedPtr<T>>(parent, name).
    define_attr("step", &Tests::DerivedPtr<T>::step).
    define_constructor(Constructor<Tests::DerivedPtr<T>>()).
    define_constructor(Constructor<Tests::DerivedPtr<T>, T*, int>(),
      std::conditional_t<std::is_fundamental_v<T>, ArgBuffer, Arg>("data_"), Arg("step_"));
}

template<typename P>
inline Rice::Data_Type<Tests::WarperBase<P>> WarperBase_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Tests::WarperBase<P>>(parent, name).
    define_attr("projector", &Tests::WarperBase<P>::projector).
    template define_method<void(Tests::WarperBase<P>::*)(const P&)>("set_projector", &Tests::WarperBase<P>::setProjector,
      Arg("p"));
}

template<typename _Tp, int m, int n>
inline Rice::Data_Type<Tests::Matx<_Tp, m, n>> Matx_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Tests::Matx<_Tp, m, n>>(parent, name).
    define_constant("Rows", Tests::Matx<_Tp, m, n>::rows).
    define_constant("Cols", Tests::Matx<_Tp, m, n>::cols).
    define_attr("val", &Tests::Matx<_Tp, m, n>::val, Rice::AttrAccess::Read).
    define_constructor(Constructor<Tests::Matx<_Tp, m, n>>()).
    template define_method<_Tp(Tests::Matx<_Tp, m, n>::*)(const Tests::Matx<_Tp, m, n>&) const>("dot", &Tests::Matx<_Tp, m, n>::dot,
      Arg("other"));
}

template<typename _Tp, int cn>
inline Rice::Data_Type<Tests::Vec<_Tp, cn>> Vec_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Tests::Vec<_Tp, cn>>(parent, name).
    define_constant("Channels", Tests::Vec<_Tp, cn>::channels).
    define_constructor(Constructor<Tests::Vec<_Tp, cn>>()).
    template define_method<_Tp(Tests::Vec<_Tp, cn>::*)(const Tests::Vec<_Tp, cn>&) const>("cross", &Tests::Vec<_Tp, cn>::cross,
      Arg("other"));
}

template<typename _Tp>
inline Rice::Data_Type<Tests::Mat_<_Tp>> Mat__instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Tests::Mat_<_Tp>>(parent, name).
    define_constructor(Constructor<Tests::Mat_<_Tp>>()).
    define_constructor(Constructor<Tests::Mat_<_Tp>, int, int>(),
      Arg("rows_"), Arg("cols_")).
    template define_method<_Tp&(Tests::Mat_<_Tp>::*)(int, int)>("at", &Tests::Mat_<_Tp>::at,
      Arg("row"), Arg("col"));
}

