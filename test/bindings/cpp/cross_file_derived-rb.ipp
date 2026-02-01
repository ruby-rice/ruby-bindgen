template<typename Data_Type_T, typename T, int N>
inline void DerivedVector_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<CrossFile::DerivedVector<T, N>>()).
    template define_method<T(CrossFile::DerivedVector<T, N>::*)(const CrossFile::DerivedVector<T, N>&) const>("dot", &CrossFile::DerivedVector<T, N>::dot,
      Arg("other"));
};

