// Test cases for FFI version guards:
// 1. Macro definitions should become Ruby constants
// 2. Unversioned functions should appear without guards
// 3. Versioned functions should be wrapped in if / end
// 4. Versioned structs should be wrapped in if / end
// 5. Versioned enums should be wrapped in if / end
// 6. Versioned typedefs should be wrapped in if / end

#define TEST_VERSION 25000

// --- Unversioned (always present) ---

int stableFunction(int x);

struct StableStruct
{
    int x;
    int y;
};

enum StableEnum
{
    STABLE_A = 0,
    STABLE_B = 1
};

typedef int StableTypedef;

// --- Versioned at 20000 ---

void newFunction(double a);

struct NewStruct
{
    int a;
    int b;
};

enum NewEnum
{
    NEW_A = 10,
    NEW_B = 20
};

typedef double NewTypedef;

// --- Versioned at 30000 ---

int futureFunction(int a, int b);

// --- Versioned at 20000 with override ---

int overriddenFunction(int x, int y, int z);
