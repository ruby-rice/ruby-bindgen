// Test cases for template default arguments
// When a template has default arguments, ruby-bindgen must include them
// in the builder call even if they weren't in the original typedef

template<typename T, int Rows, int Cols = 1>
class Matrix
{
public:
    T data[Rows * Cols];
    int rows() const { return Rows; }
    int cols() const { return Cols; }
};

// These typedefs use default template argument (Cols = 1)
typedef Matrix<int, 2> Matrix2i;       // Matrix<int, 2, 1>
typedef Matrix<double, 3> Matrix3d;    // Matrix<double, 3, 1>
typedef Matrix<float, 4> Matrix4f;     // Matrix<float, 4, 1>

// These typedefs specify all arguments
typedef Matrix<int, 2, 2> Matrix22i;
typedef Matrix<double, 3, 3> Matrix33d;

// Template with multiple defaults
template<typename T, int A = 10, int B = 20, int C = 30>
class MultiDefault
{
public:
    static constexpr int sum = A + B + C;
};

typedef MultiDefault<int> MultiDefaultInt;           // MultiDefault<int, 10, 20, 30>
typedef MultiDefault<int, 5> MultiDefaultInt5;       // MultiDefault<int, 5, 20, 30>
typedef MultiDefault<int, 5, 15> MultiDefaultInt515; // MultiDefault<int, 5, 15, 30>
typedef MultiDefault<int, 5, 15, 25> MultiDefaultInt51525; // All specified

// Template with type default
template<typename T, typename U = int>
class TypeDefault
{
public:
    T first;
    U second;
};

typedef TypeDefault<double> TypeDefaultDouble;      // TypeDefault<double, int>
typedef TypeDefault<double, float> TypeDefaultDF;   // TypeDefault<double, float>
