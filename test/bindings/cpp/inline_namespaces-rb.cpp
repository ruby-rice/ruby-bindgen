#include <inline_namespaces.hpp>
#include "inline_namespaces-rb.hpp"

using namespace Rice;



void Init_InlineNamespaces()
{
  Class(rb_cObject).define_constant("OPENCV_DNN_API_VERSION", OPENCV_DNN_API_VERSION);

  Module rb_mCv = define_module("Cv");

  Module rb_mCvDnn = define_module_under(rb_mCv, "Dnn");

  Module rb_mCvDnnDnn4V20241223 = define_module_under(rb_mCvDnn, "Dnn4V20241223");


  Rice::Data_Type<cv::dnn::dnn4_v20241223::Net> rb_cCvDnnDnn4V20241223Net = define_class_under<cv::dnn::dnn4_v20241223::Net>(rb_mCvDnnDnn4V20241223, "Net").
    define_constructor(Constructor<cv::dnn::dnn4_v20241223::Net>()).
    define_attr("layers", &cv::dnn::dnn4_v20241223::Net::layers);

  Module rb_mCvMcc = define_module_under(rb_mCv, "Mcc");

  Rice::Data_Type<cv::mcc::CCheckerDetector> rb_cCvMccCCheckerDetector = define_class_under<cv::mcc::CCheckerDetector>(rb_mCvMcc, "CCheckerDetector").
    define_constructor(Constructor<cv::mcc::CCheckerDetector>()).
    define_method<bool(cv::mcc::CCheckerDetector::*)(cv::dnn::Net)>("set_net", &cv::mcc::CCheckerDetector::setNet,
      Arg("net"));

}
