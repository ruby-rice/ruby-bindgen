#include <default_values.hpp>
#include "default_values-rb.hpp"

using namespace Rice;

Rice::Class rb_cAffine3d;
Rice::Class rb_cAffine3f;
Rice::Class rb_cCvMat;
Rice::Class rb_cCvRange;
Rice::Class rb_cNoncopyableCopyable;
Rice::Class rb_cNoncopyableDerivedFromCpp03;
Rice::Class rb_cNoncopyableDerivedFromCpp11;
Rice::Class rb_cNoncopyableNonCopyableCpp03;
Rice::Class rb_cNoncopyableNonCopyableCpp11;
Rice::Class rb_cRect;
Rice::Class rb_cRect2d;

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

  rb_cCvRange = define_class_under<cv::Range>(rb_mCv, "Range").
    define_constructor(Constructor<cv::Range>()).
    define_constructor(Constructor<cv::Range, int, int>(),
      Arg("start"), Arg("end")).
    define_attr("start", &cv::Range::start).
    define_attr("end", &cv::Range::end).
    define_singleton_function("all", &cv::Range::all);

  rb_cCvMat = define_class_under<cv::Mat>(rb_mCv, "Mat").
    define_constructor(Constructor<cv::Mat>()).
    define_constructor(Constructor<cv::Mat, const cv::Mat&, const cv::Range&, const cv::Range&>(),
      Arg("m"), Arg("row_range"), Arg("col_range") = static_cast<const cv::Range&>(cv::Range::all()));

  rb_cAffine3f = define_class_under<cv::Affine3<float>>(rb_mCv, "Affine3f").
    define(&Affine3_builder<Data_Type<cv::Affine3<float>>, float>);

  rb_cAffine3d = define_class_under<cv::Affine3<double>>(rb_mCv, "Affine3d").
    define(&Affine3_builder<Data_Type<cv::Affine3<double>>, double>);

  rb_cRect = define_class_under<cv::Rect_<int>>(rb_mCv, "Rect").
    define(&Rect__builder<Data_Type<cv::Rect_<int>>, int>);

  rb_cRect2d = define_class_under<cv::Rect_<double>>(rb_mCv, "Rect2d").
    define(&Rect__builder<Data_Type<cv::Rect_<double>>, double>);

  rb_mCv.define_module_function("render", &cv::render,
    Arg("wnd_rect") = static_cast<const cv::Rect_<double>&>(cv::Rect_<double>(0.0, 0.0, 1.0, 1.0)));

  Module rb_mIo = define_module("Io");

  rb_mIo.define_module_function("print_to", &io::print_to,
    Arg("stream") = static_cast<FILE*>(stdout));

  Module rb_mNoncopyable = define_module("Noncopyable");

  rb_cNoncopyableNonCopyableCpp03 = define_class_under<noncopyable::NonCopyableCpp03>(rb_mNoncopyable, "NonCopyableCpp03").
    define_constructor(Constructor<noncopyable::NonCopyableCpp03>()).
    define_constructor(Constructor<noncopyable::NonCopyableCpp03, int>(),
      Arg("value")).
    define_method("get_value", &noncopyable::NonCopyableCpp03::get_value);

  rb_cNoncopyableNonCopyableCpp11 = define_class_under<noncopyable::NonCopyableCpp11>(rb_mNoncopyable, "NonCopyableCpp11").
    define_constructor(Constructor<noncopyable::NonCopyableCpp11>()).
    define_constructor(Constructor<noncopyable::NonCopyableCpp11, int>(),
      Arg("value")).
    define_method("get_value", &noncopyable::NonCopyableCpp11::get_value);

  rb_mNoncopyable.define_module_function("use_cpp03", &noncopyable::use_cpp03,
    Arg("obj"));

  rb_mNoncopyable.define_module_function("use_cpp11", &noncopyable::use_cpp11,
    Arg("obj"));

  rb_cNoncopyableCopyable = define_class_under<noncopyable::Copyable>(rb_mNoncopyable, "Copyable").
    define_constructor(Constructor<noncopyable::Copyable>()).
    define_constructor(Constructor<noncopyable::Copyable, int>(),
      Arg("value")).
    define_attr("value", &noncopyable::Copyable::value);

  rb_mNoncopyable.define_module_function("use_copyable", &noncopyable::use_copyable,
    Arg("obj") = static_cast<const noncopyable::Copyable&>(noncopyable::Copyable()));

  rb_cNoncopyableDerivedFromCpp03 = define_class_under<noncopyable::DerivedFromCpp03, noncopyable::NonCopyableCpp03>(rb_mNoncopyable, "DerivedFromCpp03").
    define_constructor(Constructor<noncopyable::DerivedFromCpp03>()).
    define_constructor(Constructor<noncopyable::DerivedFromCpp03, int, int>(),
      Arg("value"), Arg("extra"));

  rb_cNoncopyableDerivedFromCpp11 = define_class_under<noncopyable::DerivedFromCpp11, noncopyable::NonCopyableCpp11>(rb_mNoncopyable, "DerivedFromCpp11").
    define_constructor(Constructor<noncopyable::DerivedFromCpp11>()).
    define_constructor(Constructor<noncopyable::DerivedFromCpp11, int, int>(),
      Arg("value"), Arg("extra"));

  rb_mNoncopyable.define_module_function("use_derived_cpp03", &noncopyable::use_derived_cpp03,
    Arg("obj"));

  rb_mNoncopyable.define_module_function("use_derived_cpp11", &noncopyable::use_derived_cpp11,
    Arg("obj"));
}