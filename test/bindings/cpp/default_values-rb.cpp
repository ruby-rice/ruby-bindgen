#include <default_values.hpp>
#include "default_values-rb.hpp"

using namespace Rice;

Rice::Class rb_cCvMat;
Rice::Class rb_cCvRange;

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

}