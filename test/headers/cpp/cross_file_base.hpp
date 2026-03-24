// Base template class with typedef - tests that typedefs from included
// headers are found when generating bindings for derived classes.

#include "cross_file_forward_decl.hpp"

namespace CrossFile
{
  template<typename T, int N>
  class BaseMatrix
  {
  public:
    T data[N];
    BaseMatrix() {}
    T sum() const { T s = 0; for(int i=0; i<N; i++) s += data[i]; return s; }
  };

  // Typedef for a specific instantiation
  typedef BaseMatrix<double, 4> BaseMatrix4d;

  // Typedef to a specialization before the template definition exists in this
  // file. The generator should still resolve the builder to the eventual
  // definition below, not the forward-declaration header.
  typedef ForwardVec<double, 2> EarlyForwardVec2d;

  // Defined after a separate forward declaration to reproduce cross-file
  // template base lookups that must resolve to this file, not the forward decl.
  template<typename T, int N>
  class ForwardVec
  {
  public:
    T data[N];
    ForwardVec() {}
    T sum() const { T s = 0; for(int i=0; i<N; i++) s += data[i]; return s; }
  };

  typedef ForwardVec<double, 4> ForwardVec4d;

  // Simple standalone class (not a base class of anything in derived file)
  // Used to test cross-file non-member operator references
  class Point2d
  {
  public:
    double x, y;
    Point2d() : x(0), y(0) {}
    Point2d(double x, double y) : x(x), y(y) {}
  };
}
