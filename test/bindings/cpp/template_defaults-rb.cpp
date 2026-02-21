#include <template_defaults.hpp>
#include "template_defaults-rb.hpp"

using namespace Rice;

#include "template_defaults-rb.ipp"

void Init_TemplateDefaults()
{
  Rice::Data_Type<Matrix<int, 2>> rb_cMatrix2i = Matrix_instantiate<int, 2, 1>(Rice::Module(rb_cObject), "Matrix2i");

  Rice::Data_Type<Matrix<double, 3>> rb_cMatrix3d = Matrix_instantiate<double, 3, 1>(Rice::Module(rb_cObject), "Matrix3d");

  Rice::Data_Type<Matrix<float, 4>> rb_cMatrix4f = Matrix_instantiate<float, 4, 1>(Rice::Module(rb_cObject), "Matrix4f");

  Rice::Data_Type<Matrix<int, 2, 2>> rb_cMatrix22i = Matrix_instantiate<int, 2, 2>(Rice::Module(rb_cObject), "Matrix22i");

  Rice::Data_Type<Matrix<double, 3, 3>> rb_cMatrix33d = Matrix_instantiate<double, 3, 3>(Rice::Module(rb_cObject), "Matrix33d");

  Rice::Data_Type<MultiDefault<int>> rb_cMultiDefaultInt = MultiDefault_instantiate<int, 10, 20, 30>(Rice::Module(rb_cObject), "MultiDefaultInt");

  Rice::Data_Type<MultiDefault<int, 5>> rb_cMultiDefaultInt5 = MultiDefault_instantiate<int, 5, 20, 30>(Rice::Module(rb_cObject), "MultiDefaultInt5");

  Rice::Data_Type<MultiDefault<int, 5, 15>> rb_cMultiDefaultInt515 = MultiDefault_instantiate<int, 5, 15, 30>(Rice::Module(rb_cObject), "MultiDefaultInt515");

  Rice::Data_Type<MultiDefault<int, 5, 15, 25>> rb_cMultiDefaultInt51525 = MultiDefault_instantiate<int, 5, 15, 25>(Rice::Module(rb_cObject), "MultiDefaultInt51525");

  Rice::Data_Type<TypeDefault<double>> rb_cTypeDefaultDouble = TypeDefault_instantiate<double, int>(Rice::Module(rb_cObject), "TypeDefaultDouble");

  Rice::Data_Type<TypeDefault<double, float>> rb_cTypeDefaultDF = TypeDefault_instantiate<double, float>(Rice::Module(rb_cObject), "TypeDefaultDF");

}