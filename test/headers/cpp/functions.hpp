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
