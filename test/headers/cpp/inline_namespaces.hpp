// Test inline/versioned namespaces using OpenCV's exact pattern.
//
// OpenCV uses macros to create a versioned inline namespace inside cv::dnn.
// The using-declaration makes names from the versioned namespace visible
// in cv::dnn without qualification. libclang's qualified_name reports
// "cv::dnn::dnn4_v20241223::Net" but the programmer writes "dnn::Net".
// The fully_qualified_spelling method must produce "cv::dnn::Net".
//
// This also tests cross-namespace parameter qualification: a class in a
// sibling namespace (cv::mcc) takes dnn::Net as a parameter. The generated
// binding must use the fully qualified "cv::dnn::Net".

// Replicate OpenCV's version.hpp macros exactly
#define OPENCV_DNN_API_VERSION 20241223
#define __CV_CAT__(x, y) x ## y
#define __CV_CAT_(x, y) __CV_CAT__(x, y)
#define __CV_CAT(x, y) __CV_CAT_(x, y)

#define CV__DNN_INLINE_NS __CV_CAT(dnn4_v, OPENCV_DNN_API_VERSION)
#define CV__DNN_INLINE_NS_BEGIN namespace CV__DNN_INLINE_NS {
#define CV__DNN_INLINE_NS_END }

// Forward-declare the versioned namespace and pull it into cv::dnn
namespace cv { namespace dnn { namespace CV__DNN_INLINE_NS { } using namespace CV__DNN_INLINE_NS; }}

namespace cv {
namespace dnn {
CV__DNN_INLINE_NS_BEGIN

class Net
{
public:
  int layers;
};

CV__DNN_INLINE_NS_END
}
}

namespace cv
{
  namespace mcc
  {
    class CCheckerDetector
    {
    public:
      // Parameter type "dnn::Net" should be qualified to "cv::dnn::Net"
      // even though qualified_name is "cv::dnn::dnn4_v20241223::Net"
      virtual bool setNet(dnn::Net net);
    };
  }
}
