template<typename T, int Rows, int Cols>
inline Rice::Data_Type<Matrix<T, Rows, Cols>> Matrix_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Matrix<T, Rows, Cols>>(parent, name).
    define_attr("data", &Matrix<T, Rows, Cols>::data, Rice::AttrAccess::Read).
    template define_method<int(Matrix<T, Rows, Cols>::*)() const>("rows", &Matrix<T, Rows, Cols>::rows).
    template define_method<int(Matrix<T, Rows, Cols>::*)() const>("cols", &Matrix<T, Rows, Cols>::cols);
}

template<typename T, int A, int B, int C>
inline Rice::Data_Type<MultiDefault<T, A, B, C>> MultiDefault_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<MultiDefault<T, A, B, C>>(parent, name).
    define_constant("Sum", MultiDefault<T, A, B, C>::sum);
}

template<typename T, typename U>
inline Rice::Data_Type<TypeDefault<T, U>> TypeDefault_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<TypeDefault<T, U>>(parent, name).
    define_attr("first", &TypeDefault<T, U>::first).
    define_attr("second", &TypeDefault<T, U>::second);
}

