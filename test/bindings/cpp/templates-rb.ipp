#include <templates.hpp>
#include "templates-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, int Rows, int Columns>
inline void Data_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Internal::Data<Rows, Columns>>()).
    define_constructor(Constructor<Internal::Data<Rows, Columns>, char*>(),
      Arg("type")).
    define_attr("rows", &Internal::Data<Rows, Columns>::Rows).
    define_attr("columns", &Internal::Data<Rows, Columns>::Columns).
    template define_method<int(Internal::Data<Rows, Columns>::*)()>("get_rows", &Internal::Data<Rows, Columns>::getRows).
    template define_method<int(Internal::Data<Rows, Columns>::*)()>("get_columns", &Internal::Data<Rows, Columns>::getColumns);
};

template<typename Data_Type_T, typename T, int Rows, int Columns>
inline void Matrix_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Tests::Matrix<T, Rows, Columns>>()).
    define_constructor(Constructor<Tests::Matrix<T, Rows, Columns>, const Tests::Matrix<T, Rows, Columns>&>(),
      Arg("other")).
    template define_method<Tests::Matrix<T, Rows, 1>(Tests::Matrix<T, Rows, Columns>::*)(int) const>("column", &Tests::Matrix<T, Rows, Columns>::column,
      Arg("column")).
    template define_method<Tests::Matrix<T, 1, Columns>(Tests::Matrix<T, Rows, Columns>::*)(int) const>("row", &Tests::Matrix<T, Rows, Columns>::row,
      Arg("column")).
    define_attr("data", &Tests::Matrix<T, Rows, Columns>::data).
    template define_method<void(Tests::Matrix<T, Rows, Columns>::*)(int, int)>("create", &Tests::Matrix<T, Rows, Columns>::create,
      Arg("rows"), Arg("cols")).
    template define_method<void(Tests::Matrix<T, Rows, Columns>::*)(int, const int*)>("create", &Tests::Matrix<T, Rows, Columns>::create,
      Arg("ndims"), ArgBuffer("sizes")).
    template define_singleton_function<Tests::Matrix<T, Rows, Columns>(*)(int, int)>("zeros", &Tests::Matrix<T, Rows, Columns>::zeros,
      Arg("rows"), Arg("cols")).
    template define_singleton_function<Tests::Matrix<T, Rows, Columns>(*)(int, const int*)>("zeros", &Tests::Matrix<T, Rows, Columns>::zeros,
      Arg("ndims"), ArgBuffer("sizes")).
    template define_singleton_function<Tests::Matrix<T, Rows, Columns>*(*)()>("create", &Tests::Matrix<T, Rows, Columns>::create);
};

template<typename Data_Type_T, typename T>
inline void TypeTraits_builder(Data_Type_T& klass)
{
  klass.define_constant("Type", Tests::TypeTraits<T>::type);
};

template<typename Data_Type_T, typename T>
inline void Transform_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Tests::Transform<T>>()).
    define_constructor(Constructor<Tests::Transform<T>, const typename Tests::Transform<T>::Vec3&>(),
      Arg("translation")).
    template define_method<void(Tests::Transform<T>::*)(const typename Tests::Transform<T>::Mat3&)>("set_rotation", &Tests::Transform<T>::setRotation,
      Arg("rotation")).
    template define_method<typename Tests::Transform<T>::Vec3(Tests::Transform<T>::*)() const>("get_translation", &Tests::Transform<T>::getTranslation);
};

template<typename Data_Type_T, typename T>
inline void Container_builder(Data_Type_T& klass)
{
  klass.define_attr("data", &Tests::Container<T>::data).
    define_attr("size", &Tests::Container<T>::size);
};

template<typename Data_Type_T, typename T>
inline void Wrapper_builder(Data_Type_T& klass)
{
  klass.define_constant("Type_id", (int)Tests::Wrapper<T>::type_id).
    define_attr("data", &Tests::Wrapper<T>::data);
};

template<typename Data_Type_T, typename T>
inline void DataType_builder(Data_Type_T& klass)
{
  klass.define_constant("Channels", Tests::DataType<T>::channels);
};

template<typename Data_Type_T, typename T>
inline void Point__builder(Data_Type_T& klass)
{
  klass.define_attr("x", &Tests::Point_<T>::x).
    define_attr("y", &Tests::Point_<T>::y).
    define_constructor(Constructor<Tests::Point_<T>>()).
    define_constructor(Constructor<Tests::Point_<T>, T, T>(),
      Arg("x_"), Arg("y_"));
};

template<typename Data_Type_T, typename _Tp>
inline void Mat__builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Tests::Mat_<_Tp>>()).
    define_constructor(Constructor<Tests::Mat_<_Tp>, const Tests::Point_<typename Tests::DataType<_Tp>::channel_type>&>(),
      Arg("pt")).
    define_constructor(Constructor<Tests::Mat_<_Tp>, int, int, _Tp*>(),
      Arg("rows"), Arg("cols"), std::conditional_t<std::is_fundamental_v<_Tp>, ArgBuffer, Arg>("data"));
};

