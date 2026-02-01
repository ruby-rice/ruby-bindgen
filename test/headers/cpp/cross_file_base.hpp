// Base template class with typedef - tests that typedefs from included
// headers are found when generating bindings for derived classes.

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
