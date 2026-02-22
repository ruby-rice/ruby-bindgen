// Test cases for FFI skip_symbols filtering

// --- Functions ---

// Normal function - should be INCLUDED
int includedFunction(int x);

// Function to skip by name - should be SKIPPED
void skippedFunction(int x);

// Another function to skip by name - should be SKIPPED
int alsoSkipped(double y);

// Function to skip by regex - should be SKIPPED
void internal_helper_init(void);

// Normal function - should be INCLUDED
double keepThisFunction(double a, double b);

// --- Structs ---

// Normal struct - should be INCLUDED
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
