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

  // Test unscoped enum inside a class (like cv::ogl::Buffer::Target)
  // Values should be qualified as MyNamespace::Buffer::Target::ARRAY_BUFFER
  class Buffer
  {
  public:
    // Unscoped enum inside class - values are scoped to the class
    enum Target
    {
      ARRAY_BUFFER = 0x8892,
      ELEMENT_ARRAY_BUFFER = 0x8893
    };

    Buffer();

    // Method with unscoped class enum as default value
    // Should generate: Arg("target") = static_cast<MyNamespace::Buffer::Target>(MyNamespace::Buffer::Target::ARRAY_BUFFER)
    void create(int rows, int cols, Target target = ARRAY_BUFFER);

    // Method with bare enum constant as the only default value (tests cursor_decl_ref_expr as default_expr itself)
    void bind(Target target = ARRAY_BUFFER);
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

  // Scoped enum with bitwise operators (like OpenCV's UMatUsageFlags)
  // Rice already provides &, |, ^, ~, <<, >> for enums automatically
  // So we should NOT generate bindings for these non-member operators
  enum class Flags
  {
    FLAG_NONE = 0,
    FLAG_READ = 1,
    FLAG_WRITE = 2
  };

  // Non-member bitwise operators - should NOT generate bindings (Rice provides them)
  static inline Flags operator | (Flags a, Flags b)
  {
    return static_cast<Flags>(static_cast<int>(a) | static_cast<int>(b));
  }

  static inline Flags operator & (Flags a, Flags b)
  {
    return static_cast<Flags>(static_cast<int>(a) & static_cast<int>(b));
  }

  static inline Flags& operator |= (Flags& a, Flags b)
  {
    a = a | b;
    return a;
  }
}
