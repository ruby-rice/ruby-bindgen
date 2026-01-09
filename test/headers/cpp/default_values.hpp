namespace cv
{
  class Range
  {
  public:
    Range();
    Range(int start, int end);
    static Range all();

    int start;
    int end;
  };

  class Mat
  {
  public:
    Mat();
    Mat(const Mat& m, const Range& rowRange, const Range& colRange = Range::all());
  };

  // Test default values in class templates with nested types
  // Similar to cv::Affine3<T> with Vec3::all(0) default
  template<typename T>
  class Vec3
  {
  public:
    Vec3();
    Vec3(T x, T y, T z);
    static Vec3 all(T value);
    T data[3];
  };

  template<typename T>
  class Affine3
  {
  public:
    typedef Vec3<T> Vec3Type;

    Affine3();
    // Constructor with default value using nested type's static method
    Affine3(const Vec3Type& translation, const Vec3Type& scale = Vec3Type::all(1));
  };

  typedef Affine3<float> Affine3f;
  typedef Affine3<double> Affine3d;

  // Test template type in default value (like cv::Rect_<double>)
  template<typename T>
  class Rect_
  {
  public:
    Rect_();
    Rect_(T x, T y, T width, T height);
    T x, y, width, height;
  };

  typedef Rect_<int> Rect;
  typedef Rect_<double> Rect2d;

  // Function with template type default value - should generate cv::Rect_<double>(...) not Rect_<double>(...)
  void render(const Rect_<double>& wndRect = Rect_<double>(0.0, 0.0, 1.0, 1.0));
}

// Test global namespace items - should NOT be prefixed with ::
// Global variables like stdout are often macros that break with :: prefix
#include <cstdio>

namespace io
{
  // Function with global namespace default value
  // Should generate: static_cast<FILE*>(stdout)
  // NOT: static_cast<FILE*>(::stdout)
  void print_to(FILE* stream = stdout);
}

// Test non-copyable types - default values should be skipped for these
// because Rice's Arg mechanism needs to copy the default value internally.
namespace noncopyable
{
  // C++03 style: private copy constructor
  class NonCopyableCpp03
  {
  public:
    NonCopyableCpp03();
    NonCopyableCpp03(int value);
    int get_value() const;
  private:
    NonCopyableCpp03(const NonCopyableCpp03&);            // copy disabled
    NonCopyableCpp03& operator=(const NonCopyableCpp03&); // assign disabled
    int value_;
  };

  // C++11 style: deleted copy constructor
  class NonCopyableCpp11
  {
  public:
    NonCopyableCpp11();
    NonCopyableCpp11(int value);
    int get_value() const;

    NonCopyableCpp11(const NonCopyableCpp11&) = delete;
    NonCopyableCpp11& operator=(const NonCopyableCpp11&) = delete;
  private:
    int value_;
  };

  // Functions that use non-copyable types as parameters with default values.
  // The default values should NOT be generated because the types can't be copied.
  void use_cpp03(const NonCopyableCpp03& obj = NonCopyableCpp03());
  void use_cpp11(const NonCopyableCpp11& obj = NonCopyableCpp11());

  // For comparison: a copyable type (default value SHOULD be generated)
  class Copyable
  {
  public:
    Copyable();
    Copyable(int value);
    int value;
  };

  void use_copyable(const Copyable& obj = Copyable());

  // Test inherited non-copyable: derived class inherits non-copyable base (like cv::flann::SearchParams)
  class DerivedFromCpp03 : public NonCopyableCpp03
  {
  public:
    DerivedFromCpp03();
    DerivedFromCpp03(int value, int extra);
  };

  class DerivedFromCpp11 : public NonCopyableCpp11
  {
  public:
    DerivedFromCpp11();
    DerivedFromCpp11(int value, int extra);
  };

  // These should NOT have default values because base class is non-copyable
  void use_derived_cpp03(const DerivedFromCpp03& obj = DerivedFromCpp03());
  void use_derived_cpp11(const DerivedFromCpp11& obj = DerivedFromCpp11());
}
