// Test cases for FFI filtering:
// 1. Export macros - only include functions with specified macros
// 2. Skip symbols - explicitly skip certain symbol names

#if defined(_MSC_VER)
  #define MY_EXPORT __declspec(dllexport)
#else
  #define MY_EXPORT __attribute__((visibility("default")))
#endif

// --- Export Macro Tests ---

// Exported function - should be INCLUDED when export_macros contains MY_EXPORT
MY_EXPORT int exportedFunction(int x);

// Non-exported function - should be SKIPPED when export_macros is set
void internalFunction(int x);

// Another exported function - should be INCLUDED
MY_EXPORT double anotherExported(double a, double b);

// --- Skip Symbol Tests ---

// Function to skip by name - should be SKIPPED
MY_EXPORT void skippedFunction(int x);

// Another function to skip by name - should be SKIPPED
MY_EXPORT int alsoSkipped(double y);

// Function to skip by regex - should be SKIPPED
MY_EXPORT void internal_helper_init(void);

// --- Structs ---

// Normal struct - should be INCLUDED (export macros only filter functions)
struct IncludedStruct
{
    int x;
    int y;
};

// Struct to skip by name - should be SKIPPED
struct SkippedStruct
{
    int a;
    int b;
};

// --- Enums ---

// Normal enum - should be INCLUDED
enum IncludedEnum
{
    VALUE_ONE = 0,
    VALUE_TWO = 1
};

// Enum to skip by name - should be SKIPPED
enum SkippedEnum
{
    SKIP_A = 0,
    SKIP_B = 1
};

// --- Typedefs ---

// Typedef to skip by name - should be SKIPPED
typedef int SkippedTypedef;

// Normal typedef - should be INCLUDED
typedef int IncludedTypedef;
