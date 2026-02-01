template<typename Data_Type_T, typename T, int Rows, int Cols>
inline void Matrix_builder(Data_Type_T& klass)
{
  klass.define_attr("data", &Matrix<T, Rows, Cols>::data, Rice::AttrAccess::Read).
    template define_method<int(Matrix<T, Rows, Cols>::*)() const>("rows", &Matrix<T, Rows, Cols>::rows).
    template define_method<int(Matrix<T, Rows, Cols>::*)() const>("cols", &Matrix<T, Rows, Cols>::cols);
};

template<typename Data_Type_T, typename T, int A, int B, int C>
inline void MultiDefault_builder(Data_Type_T& klass)
{
  klass.define_constant("Sum", MultiDefault<T, A, B, C>::sum);
};

template<typename Data_Type_T, typename T, typename U>
inline void TypeDefault_builder(Data_Type_T& klass)
{
  klass.define_attr("first", &TypeDefault<T, U>::first).
    define_attr("second", &TypeDefault<T, U>::second);
};

