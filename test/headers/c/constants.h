const int CONST_INT = 10;
static const int STATIC_CONST_INT = 20;
const double CONST_DOUBLE = 3.14;
const float CONST_FLOAT = 2.5f;
const char CONST_CHAR = 'A';
const long CONST_LONG = 100000L;
const unsigned int CONST_UINT = 42;

// Anonymous enum - constants should be emitted, not crash
enum { ANON_MAX_SIZE = 100, ANON_MIN_SIZE = 10 };
