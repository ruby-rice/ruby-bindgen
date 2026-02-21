#include <cross_file_base.hpp>
#include "cross_file_base-rb.hpp"

using namespace Rice;

#include "cross_file_base-rb.ipp"

void Init_CrossFileBase()
{
  Module rb_mCrossFile = define_module("CrossFile");

  Rice::Data_Type<CrossFile::BaseMatrix<double, 4>> rb_cBaseMatrix4d = BaseMatrix_instantiate<double, 4>(rb_mCrossFile, "BaseMatrix4d");

  Rice::Data_Type<CrossFile::Point2d> rb_cCrossFilePoint2d = define_class_under<CrossFile::Point2d>(rb_mCrossFile, "Point2d").
    define_attr("x", &CrossFile::Point2d::x).
    define_attr("y", &CrossFile::Point2d::y).
    define_constructor(Constructor<CrossFile::Point2d>()).
    define_constructor(Constructor<CrossFile::Point2d, double, double>(),
      Arg("x"), Arg("y"));

}