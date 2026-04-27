// Test cases for function filtering:
// 1. Deprecated - functions marked deprecated should be skipped
// 2. Export macros - only include functions with specified macros
// 3. Skip functions - explicitly skip certain function names

#if defined(_MSC_VER)
  #define MY_EXPORT __declspec(dllexport)
  #define MY_DEPRECATED __declspec(deprecated)
#else
  #define MY_EXPORT __attribute__((visibility("default")))
  #define MY_DEPRECATED __attribute__((deprecated))
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

    // Internal method (underscore suffix) - now included (use skip symbols to skip)
    void internal_();

    // --- Overload-specific skip tests ---
    // Only the (int, const int*) overload should be SKIPPED
    void overloaded(int a);                  // INCLUDED
    void overloaded(int a, const int* data); // SKIPPED by signature
    void overloaded(double a);               // INCLUDED

    // --- Deprecated field tests ---

    // Standard C++14 attribute - should be SKIPPED
    [[deprecated]] int oldStandardField;

    // GCC/MSVC vendor attribute - should be SKIPPED.
    // Mirrors OpenCV's CV_DEPRECATED_EXTERNAL, which expands to
    // __attribute__((deprecated)) on GCC and __declspec(deprecated) on MSVC.
    MY_DEPRECATED int oldVendorField;

    // Multi-declarator with vendor attribute applied via shared specifier -
    // every declarator should be SKIPPED. Mirrors:
    //   CV_DEPRECATED_EXTERNAL Size kernel, stride, pad, dilation;
    // from cv::dnn::BaseConvolutionLayer.
    MY_DEPRECATED int kernel, stride, pad;

    // Normal field - should be INCLUDED
    int normalField;
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

  // This class will be in symbols list - should be SKIPPED entirely
  class MY_EXPORT SkippedClass
  {
  public:
    SkippedClass();
    void method();
  };

  // --- Skipped Template Class Tests ---

  // Template class in symbols - builder should NOT be generated
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
    // This constructor should be skipped because SkippedTemplateClass is in symbols
    UsesSkippedType(const SkippedTemplateClass<T>& skipped);
    void normalMethod();
    // This method should be skipped because its parameter references a skipped type
    void methodWithSkippedParam(const SkippedTemplateClass<T>& skipped);

    // Anonymous enum with a sentinel — _dummy_enum_finalizer should be SKIPPED via symbols
    // (like OpenCV's cv::Vec::_dummy_enum_finalizer pattern)
    enum { NORMAL_CONST = 42, _dummy_enum_finalizer = 0 };

    // Field that should be SKIPPED via symbols
    T _skipped_field;
    // Field that should be INCLUDED
    T normal_field;
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

  // This specialization should be SKIPPED because SkippedArgType is in symbols
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

    // Conversion operator skipped via symbols - should be SKIPPED
    operator float() const;
  };

  // --- Inline Namespace Tests ---
  // Symbols inside inline namespaces should be matchable without the inline namespace qualifier

  inline namespace guard_v1
  {
    class MY_EXPORT GuardedClass
    {
    public:
      GuardedClass();

      // This constructor should be SKIPPED via "Outer::GuardedClass::GuardedClass(const int*)"
      // even though the actual parent chain is Outer::guard_v1::GuardedClass
      GuardedClass(const int* data);

      void normalMethod();
    };
  }

  // --- Word boundary tests for skip matching ---
  // "SkippedClass" is in the skip list, but "SkippedClassExtended" should NOT be skipped
  // (must not substring-match). Similarly, "SkippedClassHelper" should NOT be skipped.

  class MY_EXPORT SkippedClassExtended
  {
  public:
    SkippedClassExtended();
    void work();
  };

  // Method taking SkippedClassExtended should be INCLUDED (not skipped)
  class MY_EXPORT UsesNonSkippedType
  {
  public:
    UsesNonSkippedType();
    UsesNonSkippedType(const SkippedClassExtended& ext);
    void process(SkippedClassExtended* ext);
  };

  // --- Methods/functions with skipped return types ---

  class MY_EXPORT HasSkippedReturnType
  {
  public:
    HasSkippedReturnType();
    // This method returns a skipped type - should be SKIPPED
    SkippedClass* getSkipped();
    // This method returns a non-skipped type - should be INCLUDED
    int getNormal();
  };

  // Free function returning a skipped type - should be SKIPPED
  MY_EXPORT SkippedClass* createSkipped();
  // Free function returning a non-skipped type - should be INCLUDED
  MY_EXPORT int createNormal();

  // --- Namespace-qualified parameter type tests ---
  // When a constructor takes a same-namespace type, clang may spell
  // the arg type without the namespace (e.g., "MyParam" instead of "Outer::MyParam").
  // The skip entry uses the fully qualified form, so we need to match both.

  class MY_EXPORT MyParam
  {
  public:
    int value;
  };

  class MY_EXPORT ConstructorWithNsParam
  {
  public:
    ConstructorWithNsParam();

    // SKIP via "Outer::ConstructorWithNsParam::ConstructorWithNsParam(const Outer::MyParam*)"
    // Clang will spell this as "const MyParam *" (unqualified) in arg_type
    ConstructorWithNsParam(const MyParam* param);

    void doWork();
  };

  // --- Namespace-qualified typedef alias parameter tests ---
  // fully_qualified_name preserves typedef aliases where canonical spelling
  // expands them. The skip entry uses the alias form:
  //   Outer::takeAlias(Outer::MyParamAlias)
  // so build_candidates needs to include that exact candidate.

  using MyParamAlias = MyParam;

  // SKIP via "Outer::takeAlias(Outer::MyParamAlias)"
  MY_EXPORT void takeAlias(MyParamAlias value);

  // --- Non-type function template specialization skip tests ---
  // Clang reports explicit function template specializations with display names
  // like takeValue<>(), so build_candidates needs cursor template args to recover:
  //   Outer::takeValue<7>()

  template<int N>
  int takeValue() { return N; }

  template<>
  MY_EXPORT int takeValue<7>() { return 7; }

  // --- Skipped Enum Tests ---

  // This enum should be SKIPPED via symbols
  enum class SkippedEnum { A, B, C };

  // This enum should be INCLUDED (not in skip list)
  enum class IncludedEnum { X, Y, Z };

  // --- Skipped Union Tests ---

  // This union should be SKIPPED via symbols
  union SkippedUnion { int i; float f; };

  // This union should be INCLUDED (not in skip list)
  union IncludedUnion { int i; double d; };

  // --- Skipped Variable Tests ---

  // This variable should be SKIPPED via symbols
  MY_EXPORT extern const int skippedVariable;

  // This variable should be INCLUDED (not in skip list)
  MY_EXPORT extern const int includedVariable;

  // --- Nested template argument skip tests ---
  // Tests that skip matching works with nested angle brackets like Vec<float, 3>

  template<typename T, int N>
  class Vec
  {
  public:
    T data[N];
  };

  template<typename T>
  class MY_EXPORT DataType
  {
  public:
    DataType();
    void info();
  };

  // This specialization should be SKIPPED via "Outer::DataType<Outer::Vec<float, 3>>"
  template<> class MY_EXPORT DataType<Vec<float, 3>>
  {
  public:
    DataType();
    void info();
  };

  // --- Skip constructor by qualified name with template args ---
  // Tests that build_candidates replaces the last occurrence of the spelling,
  // not the first (namespace). "Outer::DataType<int>::DataType(const int*)"
  // must match, not "Outer::DataType<int>::DataType<int>(const int*)"
  template<> class MY_EXPORT DataType<double>
  {
  public:
    DataType();
    // This constructor should be SKIPPED via qualified name
    DataType(const double* data);
    void info();
  };

  // This specialization should be INCLUDED (not in skip list)
  template<> class MY_EXPORT DataType<int>
  {
  public:
    DataType();
    void info();
  };
}
