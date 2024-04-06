#include <templates.hpp>
#include "templates-rb.hpp"

using namespace Rice;

template<typename Data_Object_T, int Rows, int Columns>
inline void Data_builder(Data_Object_T& klass)
{
};

template<typename Data_Object_T, typename T, int Rows, int Columns>
inline void Matrix_builder(Data_Object_T& klass)
{
  klass.define_constructor(Constructor<Tests::Matrix<T, Rows, Columns>>()).
    define_constructor(Constructor<Tests::Matrix<T, Rows, Columns>, const Matrix<T, Rows, Columns>&>()).
    define_method<Matrix<T, Rows, 1>(Tests::Matrix<T, Rows, Columns>::*)(int) const>("column", &Tests::Matrix<T, Rows, Columns>::column).
    define_method<Matrix<T, 1, Columns>(Tests::Matrix<T, Rows, Columns>::*)(int) const>("row", &Tests::Matrix<T, Rows, Columns>::row).
    define_attr("data", &Tests::Matrix<T, Rows, Columns>::data);
};


extern "C"
void Init_Templates()
{
  Module rb_mDetail = define_module("Detail");
  
  
  Module rb_mTests = define_module("Tests");
  
  Class rb_cMatrixInt22 = define_class_under<Matrix<int, 2, 2>>(rb_mTests, "MatrixInt22");
  rb_cMatrixInt22.define(&Matrix_builder<Data_Type<Matrix<int, 2, 2>, int, 2, 2>);
}