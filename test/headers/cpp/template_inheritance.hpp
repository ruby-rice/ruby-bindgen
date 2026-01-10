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
}
