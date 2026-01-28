#include <template_defaults.hpp>
#include "template_defaults-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T, int Rows, int Cols>
inline void Matrix_builder(Data_Type_T& klass)
{
  klass.define_attr("data", &Matrix<T, Rows, Cols>::data, Rice::AttrAccess::Read).
    define_method("rows", &Matrix<T, Rows, Cols>::rows).
    define_method("cols", &Matrix<T, Rows, Cols>::cols);
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

void Init_TemplateDefaults()
{
  Rice::Data_Type<Matrix<int, 2>> rb_cMatrix2i = define_class<Matrix<int, 2>>("Matrix2i").
    define(&Matrix_builder<Data_Type<Matrix<int, 2>>, int, 2, 1>);

  Rice::Data_Type<Matrix<double, 3>> rb_cMatrix3d = define_class<Matrix<double, 3>>("Matrix3d").
    define(&Matrix_builder<Data_Type<Matrix<double, 3>>, double, 3, 1>);

  Rice::Data_Type<Matrix<float, 4>> rb_cMatrix4f = define_class<Matrix<float, 4>>("Matrix4f").
    define(&Matrix_builder<Data_Type<Matrix<float, 4>>, float, 4, 1>);

  Rice::Data_Type<Matrix<int, 2, 2>> rb_cMatrix22i = define_class<Matrix<int, 2, 2>>("Matrix22i").
    define(&Matrix_builder<Data_Type<Matrix<int, 2, 2>>, int, 2, 2>);

  Rice::Data_Type<Matrix<double, 3, 3>> rb_cMatrix33d = define_class<Matrix<double, 3, 3>>("Matrix33d").
    define(&Matrix_builder<Data_Type<Matrix<double, 3, 3>>, double, 3, 3>);

  Rice::Data_Type<MultiDefault<int>> rb_cMultiDefaultInt = define_class<MultiDefault<int>>("MultiDefaultInt").
    define(&MultiDefault_builder<Data_Type<MultiDefault<int>>, int, 10, 20, 30>);

  Rice::Data_Type<MultiDefault<int, 5>> rb_cMultiDefaultInt5 = define_class<MultiDefault<int, 5>>("MultiDefaultInt5").
    define(&MultiDefault_builder<Data_Type<MultiDefault<int, 5>>, int, 5, 20, 30>);

  Rice::Data_Type<MultiDefault<int, 5, 15>> rb_cMultiDefaultInt515 = define_class<MultiDefault<int, 5, 15>>("MultiDefaultInt515").
    define(&MultiDefault_builder<Data_Type<MultiDefault<int, 5, 15>>, int, 5, 15, 30>);

  Rice::Data_Type<MultiDefault<int, 5, 15, 25>> rb_cMultiDefaultInt51525 = define_class<MultiDefault<int, 5, 15, 25>>("MultiDefaultInt51525").
    define(&MultiDefault_builder<Data_Type<MultiDefault<int, 5, 15, 25>>, int, 5, 15, 25>);

  Rice::Data_Type<TypeDefault<double>> rb_cTypeDefaultDouble = define_class<TypeDefault<double>>("TypeDefaultDouble").
    define(&TypeDefault_builder<Data_Type<TypeDefault<double>>, double, int>);

  Rice::Data_Type<TypeDefault<double, float>> rb_cTypeDefaultDF = define_class<TypeDefault<double, float>>("TypeDefaultDF").
    define(&TypeDefault_builder<Data_Type<TypeDefault<double, float>>, double, float>);
}