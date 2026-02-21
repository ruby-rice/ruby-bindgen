#include <default_values.hpp>
#include "default_values-rb.hpp"

using namespace Rice;

#include "default_values-rb.ipp"

void Init_DefaultValues()
{
  Module rb_mCv = define_module("Cv");

  Rice::Data_Type<cv::Range> rb_cCvRange = define_class_under<cv::Range>(rb_mCv, "Range").
    define_constructor(Constructor<cv::Range>()).
    define_constructor(Constructor<cv::Range, int, int>(),
      Arg("start"), Arg("end")).
    define_singleton_function<cv::Range(*)()>("all", &cv::Range::all).
    define_attr("start", &cv::Range::start).
    define_attr("end", &cv::Range::end);

  Rice::Data_Type<cv::Mat> rb_cCvMat = define_class_under<cv::Mat>(rb_mCv, "Mat").
    define_constructor(Constructor<cv::Mat>()).
    define_constructor(Constructor<cv::Mat, const cv::Mat&, const cv::Range&, const cv::Range&>(),
      Arg("m"), Arg("row_range"), Arg("col_range") = static_cast<const cv::Range&>(cv::Range::all())).
    define_constructor(Constructor<cv::Mat, int, int, void*, int>(),
      Arg("rows"), Arg("cols"), ArgBuffer("data"), Arg("step") = static_cast<int>(cv::Mat::AUTO_STEP));

  rb_cCvMat.define_constant("AUTO_STEP", (int)cv::Mat::AUTO_STEP);

  Rice::Data_Type<cv::Affine3<float>> rb_cAffine3f = Affine3_instantiate<float>(rb_mCv, "Affine3f");

  Rice::Data_Type<cv::Affine3<double>> rb_cAffine3d = Affine3_instantiate<double>(rb_mCv, "Affine3d");

  Rice::Data_Type<cv::Rect_<int>> rb_cRect = Rect__instantiate<int>(rb_mCv, "Rect");

  Rice::Data_Type<cv::Rect_<double>> rb_cRect2d = Rect__instantiate<double>(rb_mCv, "Rect2d");

  rb_mCv.define_module_function<void(*)(const cv::Rect_<double>&)>("render", &cv::render,
    Arg("wnd_rect") = static_cast<const cv::Rect_<double>&>(cv::Rect_<double>(0.0, 0.0, 1.0, 1.0)));

  Module rb_mIo = define_module("Io");

  rb_mIo.define_module_function<void(*)(FILE*)>("print_to", &io::print_to,
    Arg("stream") = static_cast<FILE*>(stdout));

  Module rb_mMl = define_module("Ml");

  Rice::Data_Type<ml::ParamGrid> rb_cMlParamGrid = define_class_under<ml::ParamGrid>(rb_mMl, "ParamGrid").
    define_constructor(Constructor<ml::ParamGrid>()).
    define_constructor(Constructor<ml::ParamGrid, double, double, double>(),
      Arg("min_val"), Arg("max_val"), Arg("log_step")).
    define_attr("min_val", &ml::ParamGrid::minVal).
    define_attr("max_val", &ml::ParamGrid::maxVal).
    define_attr("log_step", &ml::ParamGrid::logStep);

  Rice::Data_Type<ml::SVM> rb_cMlSVM = define_class_under<ml::SVM>(rb_mMl, "SVM").
    define_constructor(Constructor<ml::SVM>()).
    define_singleton_function<ml::ParamGrid(*)(int)>("get_default_grid", &ml::SVM::getDefaultGrid,
      Arg("param_id")).
    define_method<bool(ml::SVM::*)(int, ml::ParamGrid)>("train_auto", &ml::SVM::trainAuto,
      Arg("k_fold") = static_cast<int>(10), Arg("cgrid") = static_cast<ml::ParamGrid>(ml::SVM::getDefaultGrid(ml::SVM::ParamTypes::C)));

  Enum<ml::SVM::ParamTypes> rb_cMlSVMParamTypes = define_enum_under<ml::SVM::ParamTypes>("ParamTypes", rb_cMlSVM).
    define_value("C", ml::SVM::ParamTypes::C).
    define_value("GAMMA", ml::SVM::ParamTypes::GAMMA);

  Module rb_mNoncopyable = define_module("Noncopyable");

  Rice::Data_Type<noncopyable::NonCopyableCpp03> rb_cNoncopyableNonCopyableCpp03 = define_class_under<noncopyable::NonCopyableCpp03>(rb_mNoncopyable, "NonCopyableCpp03").
    define_constructor(Constructor<noncopyable::NonCopyableCpp03>()).
    define_constructor(Constructor<noncopyable::NonCopyableCpp03, int>(),
      Arg("value")).
    define_method<int(noncopyable::NonCopyableCpp03::*)() const>("get_value", &noncopyable::NonCopyableCpp03::get_value);

  Rice::Data_Type<noncopyable::NonCopyableCpp11> rb_cNoncopyableNonCopyableCpp11 = define_class_under<noncopyable::NonCopyableCpp11>(rb_mNoncopyable, "NonCopyableCpp11").
    define_constructor(Constructor<noncopyable::NonCopyableCpp11>()).
    define_constructor(Constructor<noncopyable::NonCopyableCpp11, int>(),
      Arg("value")).
    define_method<int(noncopyable::NonCopyableCpp11::*)() const>("get_value", &noncopyable::NonCopyableCpp11::get_value);

  rb_mNoncopyable.define_module_function<void(*)(const noncopyable::NonCopyableCpp03&)>("use_cpp03", &noncopyable::use_cpp03,
    Arg("obj"));

  rb_mNoncopyable.define_module_function<void(*)(const noncopyable::NonCopyableCpp11&)>("use_cpp11", &noncopyable::use_cpp11,
    Arg("obj"));

  Rice::Data_Type<noncopyable::Copyable> rb_cNoncopyableCopyable = define_class_under<noncopyable::Copyable>(rb_mNoncopyable, "Copyable").
    define_constructor(Constructor<noncopyable::Copyable>()).
    define_constructor(Constructor<noncopyable::Copyable, int>(),
      Arg("value")).
    define_attr("value", &noncopyable::Copyable::value);

  rb_mNoncopyable.define_module_function<void(*)(const noncopyable::Copyable&)>("use_copyable", &noncopyable::use_copyable,
    Arg("obj") = static_cast<const noncopyable::Copyable&>(noncopyable::Copyable()));

  Rice::Data_Type<noncopyable::DerivedFromCpp03> rb_cNoncopyableDerivedFromCpp03 = define_class_under<noncopyable::DerivedFromCpp03, noncopyable::NonCopyableCpp03>(rb_mNoncopyable, "DerivedFromCpp03").
    define_constructor(Constructor<noncopyable::DerivedFromCpp03>()).
    define_constructor(Constructor<noncopyable::DerivedFromCpp03, int, int>(),
      Arg("value"), Arg("extra"));

  Rice::Data_Type<noncopyable::DerivedFromCpp11> rb_cNoncopyableDerivedFromCpp11 = define_class_under<noncopyable::DerivedFromCpp11, noncopyable::NonCopyableCpp11>(rb_mNoncopyable, "DerivedFromCpp11").
    define_constructor(Constructor<noncopyable::DerivedFromCpp11>()).
    define_constructor(Constructor<noncopyable::DerivedFromCpp11, int, int>(),
      Arg("value"), Arg("extra"));

  rb_mNoncopyable.define_module_function<void(*)(const noncopyable::DerivedFromCpp03&)>("use_derived_cpp03", &noncopyable::use_derived_cpp03,
    Arg("obj"));

  rb_mNoncopyable.define_module_function<void(*)(const noncopyable::DerivedFromCpp11&)>("use_derived_cpp11", &noncopyable::use_derived_cpp11,
    Arg("obj"));

  Module rb_mCvFisheye = define_module_under(rb_mCv, "Fisheye");

  rb_mCvFisheye.define_constant("CALIB_USE_INTRINSIC_GUESS", (int)cv::fisheye::CALIB_USE_INTRINSIC_GUESS);
  rb_mCvFisheye.define_constant("CALIB_FIX_INTRINSIC", (int)cv::fisheye::CALIB_FIX_INTRINSIC);

  rb_mCv.define_module_function<void(*)(int)>("calibrate_fisheye", &cv::calibrateFisheye,
    Arg("flags") = static_cast<int>(cv::fisheye::CALIB_FIX_INTRINSIC));

  Module rb_mOuter = define_module("Outer");

  Module rb_mOuterInner = define_module_under(rb_mOuter, "Inner");

  Rice::Data_Type<outer::inner::IndexParams> rb_cOuterInnerIndexParams = define_class_under<outer::inner::IndexParams>(rb_mOuterInner, "IndexParams").
    define_constructor(Constructor<outer::inner::IndexParams>());

  Rice::Data_Type<outer::Matcher> rb_cOuterMatcher = define_class_under<outer::Matcher>(rb_mOuter, "Matcher").
    define_constructor(Constructor<outer::Matcher, outer::inner::IndexParams*>(),
      Arg("params") = static_cast<outer::inner::IndexParams*>(outer::makePtr<outer::inner::IndexParams>()));

}
