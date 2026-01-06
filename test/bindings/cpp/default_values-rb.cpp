#include <default_values.hpp>
#include "default_values-rb.hpp"

using namespace Rice;

Rice::Class rb_cAffine3d;
Rice::Class rb_cAffine3f;
Rice::Class rb_cCvMat;
Rice::Class rb_cCvRange;

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

}