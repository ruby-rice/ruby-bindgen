template<typename T, int N>
inline Rice::Data_Type<CrossFile::BaseMatrix<T, N>> BaseMatrix_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<CrossFile::BaseMatrix<T, N>>(parent, name).
    define_attr("data", &CrossFile::BaseMatrix<T, N>::data, Rice::AttrAccess::Read).
    define_constructor(Constructor<CrossFile::BaseMatrix<T, N>>()).
    template define_method<T(CrossFile::BaseMatrix<T, N>::*)() const>("sum", &CrossFile::BaseMatrix<T, N>::sum);
}

