// Test cases for ArgBuffer and ReturnBuffer generation
// ArgBuffer: pointers to fundamental types OR double pointers (T**)
// ReturnBuffer: same for return types

#include <cstddef>

class BufferClass
{
public:
    int value;
};

// =============================================================================
// Incomplete array parameters with typedef element types
// =============================================================================

// size_t[] should preserve the typedef name, not expand to "unsigned long[]"
void processKernelDims(int dims, size_t globalsize[], size_t localsize[]);

// =============================================================================
// Functions with pointer to fundamental type parameters -> ArgBuffer
// =============================================================================

// Basic fundamental type pointers
void processIntBuffer(int* data, int size);
void processDoubleBuffer(double* values, int count);
void processCharBuffer(char* buffer, int length);
void processUnsignedBuffer(unsigned char* data, size_t size);

// Const fundamental type pointers
void readIntBuffer(const int* data, int size);
void readDoubleBuffer(const double* values, int count);

// Out parameters (single value via pointer)
void getMinMax(const double* input, int size, double* minVal, double* maxVal);

// =============================================================================
// Functions with double pointer parameters -> ArgBuffer
// =============================================================================

// Double pointers to fundamental types
void processIntArrays(int** arrays, int count);
void processStringArray(char** strings, int count);

// Double pointers to class types
void processObjectArray(BufferClass** objects, int count);
void processConstObjectArray(const BufferClass** objects, int count);

// =============================================================================
// Functions returning pointer to fundamental type -> ReturnBuffer
// =============================================================================

int* createIntBuffer(int size);
double* createDoubleBuffer(int size);
const float* getReadOnlyFloatBuffer();

// =============================================================================
// Functions returning double pointer -> ReturnBuffer
// =============================================================================

int** createIntArrays(int rows, int cols);
BufferClass** createObjectArray(int count);

// =============================================================================
// Class with buffer methods
// =============================================================================

class DataProcessor
{
public:
    // Methods with fundamental pointer params -> ArgBuffer
    void setData(int* data, int size);
    void setWeights(const double* weights, int count);

    // Methods with double pointer params -> ArgBuffer
    void setMatrices(float** matrices, int count);
    void setObjects(BufferClass** objects, int count);

    // Methods returning fundamental pointer -> ReturnBuffer
    int* getData();
    const double* getWeights();

    // Methods returning double pointer -> ReturnBuffer
    float** getMatrices();
    BufferClass** getObjects();

    // Out parameter method
    void computeStats(double* mean, double* stddev);
};

// =============================================================================
// Function pointer parameters
// =============================================================================

// Callback function type
typedef bool (*ProcessCallback)(int* data, int size, void* userData);

// Function taking a function pointer parameter
void processWithCallback(int* data, int size, ProcessCallback callback, void* userData);

// Function taking inline function pointer (not typedef)
void setFaceDetector(bool (*detector)(int*, int*, void*), void* userData);

// Class with function pointer methods
class EventHandler
{
public:
    // Method taking function pointer
    void setCallback(void (*callback)(int eventType, void* data), void* userData);

    // Method taking function pointer returning bool
    void setValidator(bool (*validate)(const char* input));
};
