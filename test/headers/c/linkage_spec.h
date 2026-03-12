// Test that declarations inside extern "C" {} blocks are visible
// when parsed as C++ (e.g., via clang_args: ["-xc++"])

#ifdef __cplusplus
extern "C" {
#endif

int extern_c_function(int x);

struct ExternCStruct
{
    int field;
    double value;
};

enum ExternCEnum
{
    EXTERN_A = 0,
    EXTERN_B = 1
};

typedef int ExternCTypedef;

#ifdef __cplusplus
}
#endif
