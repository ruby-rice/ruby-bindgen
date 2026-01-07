// Test case for deprecated functions/methods - should be skipped

namespace Outer
{
  namespace Inner
  {
    // Deprecated functions - should be SKIPPED
    __attribute__((deprecated)) void deprecatedFunction();
    __attribute__((deprecated("use newFunction instead"))) void deprecatedWithMessage();

    // Non-deprecated function - should be included
    void normalFunction();

    class MyClass
    {
    public:
      MyClass();

      // Deprecated method - should be SKIPPED
      __attribute__((deprecated)) void oldMethod();

      // Non-deprecated method - should be included
      void newMethod();
    };
  }
}
