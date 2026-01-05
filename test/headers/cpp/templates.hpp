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
    };

    typedef Matrix<int, 2, 2> MatrixInt22;
    using MatrixFloat33 = Matrix<float, 3, 3>;
}