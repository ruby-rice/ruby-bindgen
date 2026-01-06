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
}
