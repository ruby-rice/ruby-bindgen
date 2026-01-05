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
}
