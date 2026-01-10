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
