#include <templates.hpp>
#include "templates-rb.hpp"

using namespace Rice;

template<int Rows, int Columns>
inline void Data_builder(Class& klass)
{
};

template<typename T, int Rows, int Columns>
inline void Matrix_builder(Class& klass)
{
  klass.define_constructor(Constructor<Tests::Matrix::Matrix<T, Rows, Columns>>()).
    define_constructor(Constructor<Tests::Matrix::Matrix<T, Rows, Columns>, const Tests::Matrix<T, Rows, Columns>&>()).
    template define_method<Tests::Matrix<T, Rows, 1>(Tests::Matrix<T, Rows, Columns>::*)(int) const>("column", &Tests::Matrix<T, Rows, Columns>::column).
    template define_method<Tests::Matrix<T, 1, Columns>(Tests::Matrix<T, Rows, Columns>::*)(int) const>("row", &Tests::Matrix<T, Rows, Columns>::row).
    define_attr("data", &Tests::Matrix<T, Rows, Columns>::data);
};


extern "C"
void Init_Templates()
{
  Module rb_mDetail = define_module("Detail");
  
  
  Module rb_mTests = define_module("Tests");
  
  Class rb_cMatrixInt22 = define_class_under<Tests::Matrix<int, 2, 2>>(rb_mTests, "MatrixInt22");
  rb_cMatrixInt22.define(&Matrix_builder<int, 2, 2>);

}