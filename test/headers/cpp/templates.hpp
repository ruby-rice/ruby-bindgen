namespace Internal
{
    template<int Rows, int Columns>
    class Data
    {
      public:
        Data();
        Data(char* type);
        int Rows;
        int Columns;
        int getRows();
        int getColumns();
    };

    typedef Internal::Data<2, 2> Data22;
}

namespace Tests
{
    template<typename T, int Rows, int Columns>
    class Matrix
    {
    public:
        Matrix() = default;
        Matrix(const Matrix<T, Rows, Columns>& other);
        Matrix<T, Rows, 1> column(int column) const;
        Matrix<T, 1, Columns> row(int column) const;
        Internal::Data<Rows, Columns> data;

        // Overloaded instance methods require explicit signature disambiguation
        void create(int rows, int cols);
        void create(int ndims, const int* sizes);

        // Overloaded static methods require explicit signature disambiguation
        static Matrix zeros(int rows, int cols);
        static Matrix zeros(int ndims, const int* sizes);

        // Static factory - must come after instance methods for smart pointer forwarding
        static Matrix* create();
    };

    typedef Matrix<int, 2, 2> MatrixInt22;
    using MatrixFloat33 = Matrix<float, 3, 3>;

    // Test template class with static const member
    // Similar to OpenCV's ParamType<T>::type pattern
    template<typename T>
    struct TypeTraits
    {
        static const int type = 0;
    };

    template<>
    struct TypeTraits<int>
    {
        static const int type = 1;
    };

    template<>
    struct TypeTraits<float>
    {
        static const int type = 2;
    };

    template<>
    struct TypeTraits<double>
    {
        static const int type = 3;
    };

    // Test typename keyword for dependent types in class templates
    // Similar to cv::Affine3<T> with nested Vec3/Mat3 typedefs
    template<typename T>
    class Transform
    {
    public:
        // Nested type that requires 'typename' when used as parameter type
        typedef Matrix<T, 3, 1> Vec3;
        typedef Matrix<T, 3, 3> Mat3;

        Transform() = default;

        // Constructor using dependent type - needs 'typename Tests::Transform<T>::Vec3'
        Transform(const Vec3& translation);

        // Method using dependent type - needs 'typename Tests::Transform<T>::Mat3'
        void setRotation(const Mat3& rotation);

        // Method returning dependent type - needs 'typename Tests::Transform<T>::Vec3'
        Vec3 getTranslation() const;
    };

    typedef Transform<float> Transformf;
    typedef Transform<double> Transformd;

    // Test auto-instantiation of class templates used as parameter types without typedefs
    template<typename T>
    class Container
    {
    public:
        T* data;
        int size;
    };

    class Item
    {
    public:
        int value;
    };

    // Uses Container<Item> as parameter - should auto-instantiate Container<Item>
    class Consumer
    {
    public:
        Consumer(const Container<Item>& items);
    };

    // Test lowercase type names that need namespace qualification
    // Similar to cv::hfloat being used in cv::DataType<hfloat>
    class lowercase_type
    {
    public:
        int value;
    };

    template<typename T>
    class Wrapper
    {
    public:
        enum { type_id = 0 };
        T data;
    };

    typedef Wrapper<lowercase_type> WrappedLowercase;
}
