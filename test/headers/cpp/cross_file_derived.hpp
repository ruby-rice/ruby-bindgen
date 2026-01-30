// Derived class that inherits from a template in another file.
// Tests that the base class typedef (BaseMatrix4d) from cross_file_base.hpp
// is found and used instead of auto-generating BaseMatrixDouble4.

#include "cross_file_base.hpp"

namespace CrossFile
{
  template<typename T, int N>
  class DerivedVector : public BaseMatrix<T, N>
  {
  public:
    DerivedVector() : BaseMatrix<T, N>() {}
    T dot(const DerivedVector& other) const
    {
      T result = 0;
      for(int i=0; i<N; i++) result += this->data[i] * other.data[i];
      return result;
    }
  };

  // Typedef for derived - its base class BaseMatrix<double, 4> has typedef BaseMatrix4d
  typedef DerivedVector<double, 4> DerivedVector4d;

  // Non-member operator on BASE class type - should use BaseMatrix4d typedef (from included header)
  // Tests that non-member operators look up typedefs from @typedef_map
  inline BaseMatrix4d operator*(const BaseMatrix4d& m, double scalar)
  {
    BaseMatrix4d result;
    for(int i=0; i<4; i++) result.data[i] = m.data[i] * scalar;
    return result;
  }

  // Simple class to test that internal typedefs don't pollute the typedef_map
  class SimpleRange
  {
  public:
    int start, end;
    SimpleRange() : start(0), end(0) {}
    SimpleRange(int s, int e) : start(s), end(e) {}
  };

  // Class with internal typedef (like OpenCV's DataType<T> pattern)
  // The internal typedef should NOT be used for non-member operator naming
  template<typename T>
  class DataType
  {
  public:
    typedef T value_type;
    typedef value_type work_type;  // This should NOT be picked up as a typedef for T
  };

  // Non-member operator on SimpleRange - should use rb_cSimpleRange, NOT rb_cWorkType
  inline bool operator==(const SimpleRange& a, const SimpleRange& b)
  {
    return a.start == b.start && a.end == b.end;
  }
}
