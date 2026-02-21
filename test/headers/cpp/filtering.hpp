// Test cases for function filtering:
// 1. Deprecated - functions marked deprecated should be skipped
// 2. Export macros - only include functions with specified macros
// 3. Skip functions - explicitly skip certain function names

#if defined(_MSC_VER)
  #define MY_EXPORT __declspec(dllexport)
#else
  #define MY_EXPORT __attribute__((visibility("default")))
#endif

namespace Outer
{
  // --- Export Macro Tests ---

  // Exported function - should be INCLUDED when export_macros contains MY_EXPORT
  MY_EXPORT void exportedFunction();

  // Non-exported function - should be SKIPPED when export_macros is set
  void internalFunction();

  // --- Deprecated Tests ---

  // Deprecated function - should be SKIPPED
  [[deprecated]] void deprecatedFunction();

  // Deprecated with message - should be SKIPPED
  [[deprecated("use newFunction instead")]] void deprecatedWithMessage();

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
    [[deprecated]] void oldMethod();

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
    [[deprecated]] ClassWithDeprecatedConstructor(int old_param);

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

  // --- Skipped Template Class Tests ---

  // Template class in skip_symbols - builder should NOT be generated
  template<typename T>
  class SkippedTemplateClass
  {
  public:
    SkippedTemplateClass();
    void method();
    T value;
  };

  // Typedef creates instantiation, but builder should still be skipped
  typedef SkippedTemplateClass<int> SkippedTemplateClassInt;

  // --- Constructors/methods with skipped param types ---

  // Template class that has a constructor taking a skipped type
  template<typename T>
  class UsesSkippedType
  {
  public:
    UsesSkippedType();
    // This constructor should be skipped because SkippedTemplateClass is in skip_symbols
    UsesSkippedType(const SkippedTemplateClass<T>& skipped);
    void normalMethod();
  };

  typedef UsesSkippedType<int> UsesSkippedTypeInt;

  // --- Template specialization with skipped type as template argument ---

  // Skipped type used in template argument
  class SkippedArgType {};

  // Generic template (wrapper/deleter pattern like cv::DefaultDeleter)
  template<typename T>
  class Wrapper
  {
  public:
    Wrapper();
    void wrap(T* obj);
  };

  // This specialization should be SKIPPED because SkippedArgType is in skip_symbols
  template<> class MY_EXPORT Wrapper<SkippedArgType>
  {
  public:
    Wrapper();
    void wrap(SkippedArgType* obj);
  };

  // This specialization should be INCLUDED (int is not skipped)
  template<> class MY_EXPORT Wrapper<int>
  {
  public:
    Wrapper();
    void wrap(int* obj);
  };

  // --- Template class with all deprecated methods ---
  // The builder function should NOT be generated since all methods are deprecated

  template<typename T>
  class DeprecatedTemplate
  {
  public:
    [[deprecated]] DeprecatedTemplate();
    [[deprecated]] void deprecatedMethod1();
    [[deprecated]] void deprecatedMethod2();
  };

  typedef DeprecatedTemplate<int> DeprecatedTemplateInt;

  // --- Class with deprecated conversion operator ---

  class OtherClass {};

  class MY_EXPORT ClassWithDeprecatedConversion
  {
  public:
    ClassWithDeprecatedConversion();

    // Deprecated conversion operator - should be SKIPPED
    [[deprecated]] operator OtherClass&();

    // Non-deprecated conversion operator - should be INCLUDED
    operator int() const;
  };
}
