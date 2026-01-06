enum Color
{
    RED,
    BLACK,
    GREEN
};

namespace
{
  enum Language
  {
    Ruby,
    CPP,
    JavaScript
  };
}

namespace MyNamespace
{
  enum class Season
  {
    Spring,
    Summer,
    Fall,
    Winter = 7
  };

  class MyClass
  {
    public:
      static const int SOME_CONSTANT = 42;

      enum class EmbeddedEnum
      {
        Value1,
        Value2
      };

      // Enum hack that used to be needed by compilers
      enum
      {
          HACKED_CLASS_CONSTANT_1 = 43,
          HACKED_CLASS_CONSTANT_2 = 44
      };
  };

  // Unscoped enum - values are in enclosing namespace (MyNamespace::DECOMP_LU, not MyNamespace::DecompTypes::DECOMP_LU)
  enum DecompTypes
  {
    DECOMP_LU = 0,
    DECOMP_SVD = 1,
    DECOMP_CHOLESKY = 2
  };

  class Solver
  {
  public:
    // Method with unscoped enum as default value
    // Should generate: Arg("method") = static_cast<int>(MyNamespace::DECOMP_SVD)
    // NOT: Arg("method") = static_cast<int>(MyNamespace::DecompTypes::DECOMP_SVD)
    void solve(int method = DECOMP_SVD);
  };
}
