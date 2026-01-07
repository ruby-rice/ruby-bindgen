#include <default_values.hpp>
#include "default_values-rb.hpp"

using namespace Rice;

Rice::Class rb_cAffine3d;
Rice::Class rb_cAffine3f;
Rice::Class rb_cCvMat;
Rice::Class rb_cCvRange;
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

}