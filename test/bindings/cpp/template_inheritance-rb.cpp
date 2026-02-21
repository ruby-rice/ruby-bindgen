#include <template_inheritance.hpp>
#include "template_inheritance-rb.hpp"

using namespace Rice;

#include "template_inheritance-rb.ipp"

void Init_TemplateInheritance()
{
  Module rb_mTests = define_module("Tests");

  Rice::Data_Type<Tests::BasePtr<unsigned char>> rb_cBasePtrUnsignedChar = BasePtr_instantiate<unsigned char>(rb_mTests, "BasePtrUnsignedChar");
  Rice::Data_Type<Tests::DerivedPtr<unsigned char>> rb_cDerivedPtrb = DerivedPtr_instantiate<unsigned char>(rb_mTests, "DerivedPtrb");

  Rice::Data_Type<Tests::BasePtr<float>> rb_cBasePtrFloat = BasePtr_instantiate<float>(rb_mTests, "BasePtrFloat");
  Rice::Data_Type<Tests::DerivedPtr<float>> derived_ptrf = DerivedPtr_instantiate<float>(rb_mTests, "DerivedPtrf");

  Rice::Data_Type<Tests::PlaneProjector> rb_cTestsPlaneProjector = define_class_under<Tests::PlaneProjector>(rb_mTests, "PlaneProjector").
    define_attr("scale", &Tests::PlaneProjector::scale).
    define_constructor(Constructor<Tests::PlaneProjector>());

  Rice::Data_Type<Tests::WarperBase<Tests::PlaneProjector>> rb_cWarperBasePlaneProjector = WarperBase_instantiate<Tests::PlaneProjector>(rb_mTests, "WarperBasePlaneProjector");
  Rice::Data_Type<Tests::PlaneWarper> rb_cTestsPlaneWarper = define_class_under<Tests::PlaneWarper, Tests::WarperBase<Tests::PlaneProjector>>(rb_mTests, "PlaneWarper").
    define_constructor(Constructor<Tests::PlaneWarper, float>(),
      Arg("scale") = static_cast<float>(1.0f)).
    define_method<float(Tests::PlaneWarper::*)() const>("get_scale", &Tests::PlaneWarper::getScale);

  Rice::Data_Type<Tests::Matx<unsigned char, 2, 1>> rb_cMatxUnsignedChar21 = Matx_instantiate<unsigned char, 2, 1>(rb_mTests, "MatxUnsignedChar21");
  Rice::Data_Type<Tests::Vec<unsigned char, 2>> rb_cVec2b = Vec_instantiate<unsigned char, 2>(rb_mTests, "Vec2b");

  Rice::Data_Type<Tests::Matx<int, 3, 1>> rb_cMatxInt31 = Matx_instantiate<int, 3, 1>(rb_mTests, "MatxInt31");
  Rice::Data_Type<Tests::Vec<int, 3>> rb_cVec3i = Vec_instantiate<int, 3>(rb_mTests, "Vec3i");

  Rice::Data_Type<Tests::Matx<double, 4, 1>> rb_cMatxDouble41 = Matx_instantiate<double, 4, 1>(rb_mTests, "MatxDouble41");
  Rice::Data_Type<Tests::Vec<double, 4>> rb_cVec4d = Vec_instantiate<double, 4>(rb_mTests, "Vec4d");

  Rice::Data_Type<Tests::Mat> rb_cTestsMat = define_class_under<Tests::Mat>(rb_mTests, "Mat").
    define_attr("rows", &Tests::Mat::rows).
    define_attr("cols", &Tests::Mat::cols).
    define_constructor(Constructor<Tests::Mat>()).
    define_constructor(Constructor<Tests::Mat, int, int>(),
      Arg("rows_"), Arg("cols_"));

  Rice::Data_Type<Tests::Mat_<unsigned char>> rb_cMat1b = Mat__instantiate<unsigned char>(rb_mTests, "Mat1b");

  Rice::Data_Type<Tests::Mat_<float>> rb_cMat1f = Mat__instantiate<float>(rb_mTests, "Mat1f");

}