// Test cases for FFI function generation:
// 1. Regular functions
// 2. Variadic functions (printf-style)

#include <stdarg.h>

// Regular function - baseline
int add(int a, int b);

// Variadic function - should generate :varargs as last parameter
int my_printf(const char* fmt, ...);

// Variadic function with multiple fixed params
void log_message(int level, const char* category, const char* fmt, ...);

// va_list function — should be SKIPPED (va_list cannot be constructed from Ruby)
// Use the variadic version (my_printf) instead.
int my_vprintf(const char* fmt, va_list args);
