#include <filtering.hpp>
#include "filtering-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T>
inline void UsesSkippedType_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Outer::UsesSkippedType<T>>()).
    template define_method<void(Outer::UsesSkippedType<T>::*)()>("normal_method", &Outer::UsesSkippedType<T>::normalMethod);
};

template<typename Data_Type_T, typename T>
inline void Wrapper_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<Outer::Wrapper<T>>()).
    template define_method<void(Outer::Wrapper<T>::*)(T*)>("wrap", &Outer::Wrapper<T>::wrap,
      std::conditional_t<std::is_fundamental_v<T>, ArgBuffer, Arg>("obj"));
};

