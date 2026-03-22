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

namespace QualifiedDefaults
{
    enum Counts
    {
        DefaultCount = 7
    };

    struct Tag
    {
        int value;
    };

    template<typename T>
    class Box
    {
    public:
        T value;
    };

    // The typedef omits U, so the builder must instantiate with:
    //   QualifiedTypeDefault<int, QualifiedDefaults::Tag>
    // not:
    //   QualifiedTypeDefault<int, Tag>
    template<typename T, typename U = Tag>
    class QualifiedTypeDefault
    {
    public:
        T first;
        U second;
    };

    // Nested template defaults must qualify both the template and its type arg:
    //   QualifiedNestedDefault<int, QualifiedDefaults::Box<QualifiedDefaults::Tag>>
    // not:
    //   QualifiedNestedDefault<int, Box<Tag>>
    template<typename T, typename U = Box<Tag>>
    class QualifiedNestedDefault
    {
    public:
        T first;
        U second;
    };

    // Non-type defaults need the same qualification treatment when the builder
    // emits the instantiated template outside this namespace:
    //   QualifiedValueDefault<int, QualifiedDefaults::DefaultCount>
    // not:
    //   QualifiedValueDefault<int, DefaultCount>
    template<typename T, int N = DefaultCount>
    class QualifiedValueDefault
    {
    public:
        static constexpr int value = N;
    };
}

typedef QualifiedDefaults::QualifiedTypeDefault<int> QualifiedTypeDefaultInt;
typedef QualifiedDefaults::QualifiedNestedDefault<int> QualifiedNestedDefaultInt;
typedef QualifiedDefaults::QualifiedValueDefault<int> QualifiedValueDefaultInt;

namespace TemplateTemplateDefaults
{
    template<typename T>
    class Box
    {
    public:
        T value;
    };

    // Template-template defaults need to be appended when omitted from a typedef:
    //   Holder<int, TemplateTemplateDefaults::Box>
    // not:
    //   Holder<int>
    template<typename T, template<typename> class Container = Box>
    class Holder
    {
    public:
        Container<T> value;
    };

    template<typename T = int>
    class BoxWithInnerDefault
    {
    public:
        T value;
    };

    // The default separator must ignore the inner `= int` and keep the outer
    // default `= BoxWithInnerDefault` intact:
    //   HolderWithInnerDefault<float, TemplateTemplateDefaults::BoxWithInnerDefault>
    // not:
    //   HolderWithInnerDefault<float>
    template<typename T, template<typename U = int> class Container = BoxWithInnerDefault>
    class HolderWithInnerDefault
    {
    public:
        Container<T> value;
    };
}

typedef TemplateTemplateDefaults::Holder<int> HolderInt;
typedef TemplateTemplateDefaults::HolderWithInnerDefault<float> HolderWithInnerDefaultFloat;

// Top-level template arg counting must ignore commas inside nested function
// parameter lists. The typedef still omits U, so the builder must instantiate:
//   FunctionTypeDefault<void (*)(int, int), int>
// not:
//   FunctionTypeDefault<void (*)(int, int)>
template<typename T, typename U = int>
class FunctionTypeDefault
{
public:
    T first;
    U second;
};

typedef FunctionTypeDefault<void (*)(int, int)> FunctionTypeDefaultFn;
