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
