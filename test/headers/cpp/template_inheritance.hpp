#pragma once

namespace Tests
{
  // Base template class
  template <typename T>
  struct BasePtr
  {
    T* data;

    BasePtr() : data(nullptr) {}
    BasePtr(T* data_) : data(data_) {}
  };

  // Derived template class inheriting from BasePtr<T>
  template <typename T>
  struct DerivedPtr : public BasePtr<T>
  {
    int step;

    DerivedPtr() : BasePtr<T>(), step(0) {}
    DerivedPtr(T* data_, int step_) : BasePtr<T>(data_), step(step_) {}
  };

  // typedef specialization
  typedef DerivedPtr<unsigned char> DerivedPtrb;

  // using statement specialization
  using DerivedPtrf = DerivedPtr<float>;

  // Issue #37: Non-template class inheriting from template instantiation
  // The base class spelling must be fully qualified (cv::detail::RotationWarperBase<cv::detail::PlaneProjector>)
  template <typename P>
  class WarperBase
  {
  public:
    P projector;
    void setProjector(const P& p) { projector = p; }
  };

  struct PlaneProjector
  {
    float scale;
    PlaneProjector() : scale(1.0f) {}
  };

  // Non-template class with template base class
  class PlaneWarper : public WarperBase<PlaneProjector>
  {
  public:
    PlaneWarper(float scale = 1.0f) { projector.scale = scale; }
    float getScale() const { return projector.scale; }
  };

  // Issue: Derived template has fewer params than base template
  // Like OpenCV's Vec<_Tp, cn> : public Matx<_Tp, cn, 1>
  template<typename _Tp, int m, int n>
  class Matx
  {
  public:
    static constexpr int rows = m;
    static constexpr int cols = n;
    _Tp val[m * n];

    Matx() {}
    _Tp dot(const Matx& other) const { return val[0] * other.val[0]; }
  };

  template<typename _Tp, int cn>
  class Vec : public Matx<_Tp, cn, 1>
  {
  public:
    static constexpr int channels = cn;

    Vec() : Matx<_Tp, cn, 1>() {}
    _Tp cross(const Vec& other) const { return this->val[0] * other.val[0]; }
  };

  // typedef specializations that should correctly resolve base class
  typedef Vec<unsigned char, 2> Vec2b;
  typedef Vec<int, 3> Vec3i;
  typedef Vec<double, 4> Vec4d;

  // Issue: Template class inheriting from non-template class
  // Like OpenCV's Mat_<_Tp> : public Mat
  class Mat
  {
  public:
    int rows;
    int cols;

    Mat() : rows(0), cols(0) {}
    Mat(int rows_, int cols_) : rows(rows_), cols(cols_) {}
  };

  template<typename _Tp>
  class Mat_ : public Mat
  {
  public:
    Mat_() : Mat() {}
    Mat_(int rows_, int cols_) : Mat(rows_, cols_) {}

    _Tp& at(int row, int col) { return data[row * cols + col]; }

  private:
    _Tp data[100];  // simplified storage
  };

  typedef Mat_<unsigned char> Mat1b;
  typedef Mat_<float> Mat1f;
}
