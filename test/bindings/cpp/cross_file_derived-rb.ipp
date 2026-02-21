template<typename T, int N>
inline Rice::Data_Type<CrossFile::DerivedVector<T, N>> DerivedVector_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<CrossFile::DerivedVector<T, N>>(parent, name).
    define_constructor(Constructor<CrossFile::DerivedVector<T, N>>()).
    template define_method<T(CrossFile::DerivedVector<T, N>::*)(const CrossFile::DerivedVector<T, N>&) const>("dot", &CrossFile::DerivedVector<T, N>::dot,
      Arg("other"));
}


