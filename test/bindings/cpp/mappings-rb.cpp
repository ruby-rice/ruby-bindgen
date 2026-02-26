#include <mappings.hpp>
#include "mappings-rb.hpp"

using namespace Rice;

#include "mappings-rb.ipp"

void Init_Mappings()
{
  Module rb_mCv = define_module("Cv");

  Rice::Data_Type<cv::VideoCapture> rb_cCvVideoCapture = define_class_under<cv::VideoCapture>(rb_mCv, "VideoCapture").
    define_constructor(Constructor<cv::VideoCapture>()).
    define_method<bool(cv::VideoCapture::*)()>("grab", &cv::VideoCapture::grab).
    define_method<bool(cv::VideoCapture::*)(int)>("retrieve", &cv::VideoCapture::retrieve,
      Arg("flag"));

  Rice::Data_Type<cv::MatSize> rb_cCvMatSize = define_class_under<cv::MatSize>(rb_mCv, "MatSize").
    define_constructor(Constructor<cv::MatSize>()).
    define_method<int(cv::MatSize::*)() const>("to_size", &cv::MatSize::operator());

  Rice::Data_Type<cv::Mat> rb_cCvMat = define_class_under<cv::Mat>(rb_mCv, "Mat").
    define_constructor(Constructor<cv::Mat>()).
    define_method<int(cv::Mat::*)(int) const>("[]", &cv::Mat::operator(),
      Arg("i")).
    define_method<int(cv::Mat::*)(int, int) const>("[]", &cv::Mat::operator(),
      Arg("i"), Arg("j"));

  Rice::Data_Type<cv::UMat> rb_cCvUMat = define_class_under<cv::UMat>(rb_mCv, "UMat").
    define_constructor(Constructor<cv::UMat>()).
    define_method<int(cv::UMat::*)(int) const>("[]", &cv::UMat::operator(),
      Arg("i"));

  Rice::Data_Type<cv::Matx<unsigned char, 2, 1>> rb_cMatxUChar21 = Matx_instantiate<unsigned char, 2, 1>(rb_mCv, "Matx21b");

  Rice::Data_Type<cv::Matx<unsigned char, 3, 1>> rb_cMatxUChar31 = Matx_instantiate<unsigned char, 3, 1>(rb_mCv, "Matx31b");

  Rice::Data_Type<cv::Matx<short, 2, 1>> rb_cMatxShort21 = Matx_instantiate<short, 2, 1>(rb_mCv, "Matx21s");

  Rice::Data_Type<cv::Matx<int, 4, 1>> rb_cMatxInt41 = Matx_instantiate<int, 4, 1>(rb_mCv, "Matx41i");

}
