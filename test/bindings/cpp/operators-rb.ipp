#include <operators.hpp>
#include "operators-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T>
inline void DataPtr_builder(Data_Type_T& klass)
{
  klass.define_attr("data", &DataPtr<T>::data).
    define_constructor(Constructor<DataPtr<T>>()).
    define_constructor(Constructor<DataPtr<T>, T*>(),
      std::conditional_t<std::is_fundamental_v<T>, ArgBuffer, Arg>("ptr")).
    define_method("to_ptr", [](DataPtr<T>& self) -> T*
    {
      return self;
    }).
    define_method("to_const_ptr", [](const DataPtr<T>& self) -> const T*
    {
      return self;
    });
};

