#include <default_values.hpp>
#include "default_values-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T>
inline void Vec3_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<cv::Vec3<T>>()).
    define_constructor(Constructor<cv::Vec3<T>, T, T, T>(),
      Arg("x"), Arg("y"), Arg("z")).
    define_singleton_function("all", &cv::Vec3<T>::all,
      Arg("value"));
};

template<typename Data_Type_T, typename T>
inline void Affine3_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<cv::Affine3<T>>()).
    define_constructor(Constructor<cv::Affine3<T>, const typename cv::Affine3<T>::Vec3Type&, const typename cv::Affine3<T>::Vec3Type&>(),
      Arg("translation"), Arg("scale") = static_cast<const typename cv::Affine3<T>::Vec3Type&>(cv::Affine3<T>::Vec3Type::all(1)));
};

template<typename Data_Type_T, typename T>
inline void Rect__builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<cv::Rect_<T>>()).
    define_constructor(Constructor<cv::Rect_<T>, T, T, T, T>(),
      Arg("x"), Arg("y"), Arg("width"), Arg("height")).
    define_attr("x", &cv::Rect_<T>::x).
    define_attr("y", &cv::Rect_<T>::y).
    define_attr("width", &cv::Rect_<T>::width).
    define_attr("height", &cv::Rect_<T>::height);
};

void Init_DefaultValues()
{
  Module rb_mCv = define_module("Cv");

  Rice::Data_Type<cv::Range> rb_cCvRange = define_class_under<cv::Range>(rb_mCv, "Range").
    define_constructor(Constructor<cv::Range>()).
    define_constructor(Constructor<cv::Range, int, int>(),
      Arg("start"), Arg("end")).
    define_attr("start", &cv::Range::start).
    define_attr("end", &cv::Range::end).
    define_singleton_function("all", &cv::Range::all);

  Rice::Data_Type<cv::Mat> rb_cCvMat = define_class_under<cv::Mat>(rb_mCv, "Mat").
    define_constructor(Constructor<cv::Mat>()).
    define_constructor(Constructor<cv::Mat, const cv::Mat&, const cv::Range&, const cv::Range&>(),
      Arg("m"), Arg("row_range"), Arg("col_range") = static_cast<const cv::Range&>(cv::Range::all())).
    define_constructor(Constructor<cv::Mat, int, int, void*, int>(),
      Arg("rows"), Arg("cols"), ArgBuffer("data"), Arg("step") = static_cast<int>(cv::Mat::AUTO_STEP));

  rb_cCvMat.define_constant("AUTO_STEP", (int)cv::Mat::AUTO_STEP);

  Rice::Data_Type<cv::Affine3<float>> rb_cAffine3f = define_class_under<cv::Affine3<float>>(rb_mCv, "Affine3f").
    define(&Affine3_builder<Data_Type<cv::Affine3<float>>, float>);

  Rice::Data_Type<cv::Affine3<double>> rb_cAffine3d = define_class_under<cv::Affine3<double>>(rb_mCv, "Affine3d").
    define(&Affine3_builder<Data_Type<cv::Affine3<double>>, double>);

  Rice::Data_Type<cv::Rect_<int>> rb_cRect = define_class_under<cv::Rect_<int>>(rb_mCv, "Rect").
    define(&Rect__builder<Data_Type<cv::Rect_<int>>, int>);

  Rice::Data_Type<cv::Rect_<double>> rb_cRect2d = define_class_under<cv::Rect_<double>>(rb_mCv, "Rect2d").
    define(&Rect__builder<Data_Type<cv::Rect_<double>>, double>);

  rb_mCv.define_module_function("render", &cv::render,
    Arg("wnd_rect") = static_cast<const cv::Rect_<double>&>(Rect_<double>(0.0, 0.0, 1.0, 1.0)));

  Module rb_mIo = define_module("Io");

  rb_mIo.define_module_function("print_to", &io::print_to,
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
    define_method("train_auto", &ml::SVM::trainAuto,
      Arg("k_fold") = static_cast<int>(10), Arg("cgrid") = static_cast<ml::ParamGrid>(ml::SVM::getDefaultGrid(ml::SVM::ParamTypes::C))).
    define_singleton_function("get_default_grid", &ml::SVM::getDefaultGrid,
      Arg("param_id"));

  Enum<ml::SVM::ParamTypes> rb_cMlSVMParamTypes = define_enum_under<ml::SVM::ParamTypes>("ParamTypes", rb_cMlSVM).
    define_value("C", ml::SVM::ParamTypes::C).
    define_value("GAMMA", ml::SVM::ParamTypes::GAMMA);

  Module rb_mNoncopyable = define_module("Noncopyable");

  Rice::Data_Type<noncopyable::NonCopyableCpp03> rb_cNoncopyableNonCopyableCpp03 = define_class_under<noncopyable::NonCopyableCpp03>(rb_mNoncopyable, "NonCopyableCpp03").
    define_constructor(Constructor<noncopyable::NonCopyableCpp03>()).
    define_constructor(Constructor<noncopyable::NonCopyableCpp03, int>(),
      Arg("value")).
    define_method("get_value", &noncopyable::NonCopyableCpp03::get_value);

  Rice::Data_Type<noncopyable::NonCopyableCpp11> rb_cNoncopyableNonCopyableCpp11 = define_class_under<noncopyable::NonCopyableCpp11>(rb_mNoncopyable, "NonCopyableCpp11").
    define_constructor(Constructor<noncopyable::NonCopyableCpp11>()).
    define_constructor(Constructor<noncopyable::NonCopyableCpp11, int>(),
      Arg("value")).
    define_method("get_value", &noncopyable::NonCopyableCpp11::get_value);

  rb_mNoncopyable.define_module_function("use_cpp03", &noncopyable::use_cpp03,
    Arg("obj"));

  rb_mNoncopyable.define_module_function("use_cpp11", &noncopyable::use_cpp11,
    Arg("obj"));

  Rice::Data_Type<noncopyable::Copyable> rb_cNoncopyableCopyable = define_class_under<noncopyable::Copyable>(rb_mNoncopyable, "Copyable").
    define_constructor(Constructor<noncopyable::Copyable>()).
    define_constructor(Constructor<noncopyable::Copyable, int>(),
      Arg("value")).
    define_attr("value", &noncopyable::Copyable::value);

  rb_mNoncopyable.define_module_function("use_copyable", &noncopyable::use_copyable,
    Arg("obj") = static_cast<const noncopyable::Copyable&>(noncopyable::Copyable()));

  Rice::Data_Type<noncopyable::DerivedFromCpp03> rb_cNoncopyableDerivedFromCpp03 = define_class_under<noncopyable::DerivedFromCpp03, noncopyable::NonCopyableCpp03>(rb_mNoncopyable, "DerivedFromCpp03").
    define_constructor(Constructor<noncopyable::DerivedFromCpp03>()).
    define_constructor(Constructor<noncopyable::DerivedFromCpp03, int, int>(),
      Arg("value"), Arg("extra"));

  Rice::Data_Type<noncopyable::DerivedFromCpp11> rb_cNoncopyableDerivedFromCpp11 = define_class_under<noncopyable::DerivedFromCpp11, noncopyable::NonCopyableCpp11>(rb_mNoncopyable, "DerivedFromCpp11").
    define_constructor(Constructor<noncopyable::DerivedFromCpp11>()).
    define_constructor(Constructor<noncopyable::DerivedFromCpp11, int, int>(),
      Arg("value"), Arg("extra"));

  rb_mNoncopyable.define_module_function("use_derived_cpp03", &noncopyable::use_derived_cpp03,
    Arg("obj"));

  rb_mNoncopyable.define_module_function("use_derived_cpp11", &noncopyable::use_derived_cpp11,
    Arg("obj"));
}