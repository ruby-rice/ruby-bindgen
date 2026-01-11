// Test cases for function filtering:
// 1. Deprecated - functions marked deprecated should be skipped
// 2. Export macros - only include functions with specified macros
// 3. Skip functions - explicitly skip certain function names

#define MY_EXPORT __attribute__((visibility("default")))

namespace Outer
{
  // --- Export Macro Tests ---

  // Exported function - should be INCLUDED when export_macros contains MY_EXPORT
  MY_EXPORT void exportedFunction();

  // Non-exported function - should be SKIPPED when export_macros is set
  void internalFunction();

  // --- Deprecated Tests ---

  // Deprecated function - should be SKIPPED
  __attribute__((deprecated)) void deprecatedFunction();

  // Deprecated with message - should be SKIPPED
  __attribute__((deprecated("use newFunction instead"))) void deprecatedWithMessage();

  // Non-deprecated function - should be INCLUDED
  MY_EXPORT void normalFunction();

  // --- Skip Functions Tests ---

  // This function name will be in skip_functions list - should be SKIPPED
  MY_EXPORT void skippedByName();

  // Another function to skip by name - should be SKIPPED
  MY_EXPORT void alsoSkippedByName();

  // --- Variadic Function Tests ---

  // Variadic function - should be SKIPPED (can't be wrapped directly)
  MY_EXPORT void printFormatted(const char* fmt, ...);

  // Non-variadic overload - should be INCLUDED
  MY_EXPORT void printFormatted(const char* msg);

  // --- Class with mixed methods ---

  class MY_EXPORT MyClass
  {
  public:
    MyClass();

    // Deprecated method - should be SKIPPED
    __attribute__((deprecated)) void oldMethod();

    // Normal method - should be INCLUDED
    void newMethod();

    // Method to skip by name - should be SKIPPED
    void skippedMethod();

    // Internal method (underscore suffix) - should be SKIPPED
    void internal_();
  };

  // --- Class with deprecated constructor ---

  class MY_EXPORT ClassWithDeprecatedConstructor
  {
  public:
    // Deprecated constructor - should be SKIPPED
    __attribute__((deprecated)) ClassWithDeprecatedConstructor(int old_param);

    // Non-deprecated constructor - should be INCLUDED
    ClassWithDeprecatedConstructor(int param1, int param2);

    void doSomething();
  };

  // --- Skipped Class Tests ---

  // This class will be in skip_symbols list - should be SKIPPED entirely
  class MY_EXPORT SkippedClass
  {
  public:
    SkippedClass();
    void method();
  };

  // --- Class with deprecated conversion operator ---

  class OtherClass {};

  class MY_EXPORT ClassWithDeprecatedConversion
  {
  public:
    ClassWithDeprecatedConversion();

    // Deprecated conversion operator - should be SKIPPED
    __attribute__((deprecated)) operator OtherClass&();

    // Non-deprecated conversion operator - should be INCLUDED
    operator int() const;
  };
}
