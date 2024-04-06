namespace detail
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

    typedef detail::Data<2, 2> Data22;
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
        detail::Data<Rows, Columns> data;
    };

    typedef Matrix<int, 2, 2> MatrixInt22;
    using MatrixFloat33 = Matrix<float, 3, 3>;
}