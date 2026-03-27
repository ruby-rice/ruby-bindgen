#pragma once

namespace cv {
namespace gapi {
namespace oak {
struct ColorCameraParams
{
};

struct EncoderConfig
{
};
}
}

namespace detail {
template<typename T>
struct CompileArgTag
{
  static const char* tag();
};

template<>
struct CompileArgTag<gapi::oak::ColorCameraParams>
{
  static const char* tag();
};

template<>
struct CompileArgTag<gapi::oak::EncoderConfig>
{
  static const char* tag();
};
}
}
