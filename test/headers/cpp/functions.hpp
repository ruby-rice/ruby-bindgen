void someFunction(float a);
void overload(int a);
void overload(int a, int b);
// Test that stray "= " prefix is stripped from default value extent text
void overload(int a, int b, int c = 10);

// Test const pointer return type (const char * const)
const char * const getConstString();

// Test const pointer parameter (const char * const) - overloaded to force explicit type
void processString(const char* str);
void processString(const char * const str, int len);

// Test unnamed parameters (Issue #36) - should generate arg_0, arg_1, etc.
void unnamedParams(int, float, double);
void mixedParams(int named, float, double alsoNamed, int);

// Test bool return type naming (Issue #37)
// Predicate functions (no params) should get ? suffix
// Action functions (with params) should NOT get ? suffix
bool isEmpty();           // -> empty?
bool isValid();           // -> valid?
bool hasData();           // -> has_data?
bool checkValue(int x);   // -> check_value (NOT check_value?)
bool validate(int x);     // -> validate (NOT validate?)
bool process(int a, int b); // -> process (NOT process?)

// Predicate functions with "is" prefix should get ? suffix even with params (ruby-bindgen-1xq)
bool isContinuous(int i = -1);    // -> continuous?
bool isSubmatrix(int i);          // -> submatrix? (even without default)

class Widget
{
public:
  bool empty();             // -> empty?
  bool isEnabled();         // -> enabled?
  bool contains(int x);     // -> contains (NOT contains?)
  bool trySet(int value);   // -> try_set (NOT try_set?)
};

// =============================================================================
// C-style array parameters - should be namespace-qualified
// =============================================================================
namespace arrays
{
  class Element {};

  void processArray(Element arr[4]);
  void processConstArray(const Element arr[4]);
  void processIncompleteArray(Element arr[]);
}

// =============================================================================
// Non-type template arguments referencing static class members
// Similar to OpenCV's GPCPatchDescriptor::nFeatures used in Vec<double, nFeatures>
// =============================================================================
namespace nontype_args
{
  template<typename T, int N>
  class Container {};

  class Config
  {
  public:
    static constexpr int Size = 8;

    // Bare non-type arg (within the declaring class) - needs full qualification in generated code
    void process(const Container<double, Size>& data);
  };

  class User
  {
  public:
    // Partially-qualified non-type arg - Config::Size needs full qualification
    void use(const Container<double, Config::Size>& data);
  };
}

// =============================================================================
// Variadic functions - should be SKIPPED (cannot be bound to Ruby)
// =============================================================================

// C-style variadic function (printf-like)
int logMessage(int level, const char* fmt, ...);

// Class with variadic static method
class Logger
{
public:
  static void setLevel(int level);                    // -> should be generated
  static int log(int level, const char* fmt, ...);    // -> should be SKIPPED
  static int error(const char* fmt, ...);             // -> should be SKIPPED
};
