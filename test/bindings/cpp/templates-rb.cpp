#include <templates.hpp>
#include "templates-rb.hpp"

using namespace Rice;

Rice::Class rb_cData22;
Rice::Class rb_cMatrixInt22;

template<typename Data_Type_T, int Rows, int Columns>
inline void Data_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Internal::Data::Data<Rows, Columns>>()).
    define_constructor(Constructor<Internal::Data::Data<Rows, Columns>, char*>(),
      Arg("type")).
    define_attr("rows", &Internal::Data<Rows, Columns>::Rows).
    define_attr("columns", &Internal::Data<Rows, Columns>::Columns).
    define_method("get_rows", &Internal::Data<Rows, Columns>::getRows).
    define_method("get_columns", &Internal::Data<Rows, Columns>::getColumns);
};

template<typename Data_Type_T, typename T, int Rows, int Columns>
inline void Matrix_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Tests::Matrix::Matrix<T, Rows, Columns>>()).
    define_constructor(Constructor<Tests::Matrix::Matrix<T, Rows, Columns>, const Tests::Matrix<T, Rows, Columns>&>(),
      Arg("other")).
    define_method("column", &Tests::Matrix<T, Rows, Columns>::column,
      Arg("column")).
    define_method("row", &Tests::Matrix<T, Rows, Columns>::row,
      Arg("column")).
    define_attr("data", &Tests::Matrix<T, Rows, Columns>::data).
    template define_method<void(Tests::Matrix<T, Rows, Columns>::*)(int, int)>("create", &Tests::Matrix<T, Rows, Columns>::create,
      Arg("rows"), Arg("cols")).
    template define_method<void(Tests::Matrix<T, Rows, Columns>::*)(int, const int*)>("create", &Tests::Matrix<T, Rows, Columns>::create,
      Arg("ndims"), Arg("sizes")).
    template define_singleton_function<Tests::Matrix<T, Rows, Columns>(*)(int, int)>("zeros", &Tests::Matrix<T, Rows, Columns>::zeros,
      Arg("rows"), Arg("cols")).
    template define_singleton_function<Tests::Matrix<T, Rows, Columns>(*)(int, const int*)>("zeros", &Tests::Matrix<T, Rows, Columns>::zeros,
      Arg("ndims"), Arg("sizes"));
};
void Init_Templates()
{
  Module rb_mInternal = define_module("Internal");
  
  rb_cData22 = define_class_under<Internal::Data<2, 2>>(rb_mInternal, "Data22").
    define(&Data_builder<Data_Type<Internal::Data<2, 2>>, 2, 2>);
  
  Module rb_mTests = define_module("Tests");
  
  rb_cMatrixInt22 = define_class_under<Tests::Matrix<int, 2, 2>>(rb_mTests, "MatrixInt22").
    define(&Matrix_builder<Data_Type<Tests::Matrix<int, 2, 2>>, int, 2, 2>);

}