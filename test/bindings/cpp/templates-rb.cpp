#include <templates.hpp>
#include "templates-rb.hpp"

using namespace Rice;

Rice::Class rb_cData22;
Rice::Class rb_cMatrixInt22;

template<typename Data_Type_T, int Rows, int Columns>
inline void Data_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<detail::Data::Data<Rows, Columns>>()).
    define_constructor(Constructor<detail::Data::Data<Rows, Columns>, char*>(),
      Arg("type")).
    define_attr("rows", &detail::Data<Rows, Columns>::Rows).
    define_attr("columns", &detail::Data<Rows, Columns>::Columns).
    template define_method("get_rows", &detail::Data<Rows, Columns>::getRows).
    template define_method("get_columns", &detail::Data<Rows, Columns>::getColumns);
};

template<typename Data_Type_T, typename T, int Rows, int Columns>
inline void Matrix_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Tests::Matrix::Matrix<T, Rows, Columns>>()).
    define_constructor(Constructor<Tests::Matrix::Matrix<T, Rows, Columns>, const Tests::Matrix<T, Rows, Columns>&>(),
      Arg("other")).
    template define_method("column", &Tests::Matrix<T, Rows, Columns>::column,
      Arg("column")).
    template define_method("row", &Tests::Matrix<T, Rows, Columns>::row,
      Arg("column")).
    define_attr("data", &Tests::Matrix<T, Rows, Columns>::data);
};
void Init_Templates()
{
  Module rb_mDetail = define_module("Detail");
  
  rb_cData22 = define_class_under<detail::Data<2, 2>>(rb_mDetail, "Data22").
    define(&Data_builder<Data_Type<detail::Data<2, 2>>, 2, 2>);
  
  Module rb_mTests = define_module("Tests");
  
  rb_cMatrixInt22 = define_class_under<Tests::Matrix<int, 2, 2>>(rb_mTests, "MatrixInt22").
    define(&Matrix_builder<Data_Type<Tests::Matrix<int, 2, 2>>, int, 2, 2>);

}