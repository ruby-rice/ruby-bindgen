#include <incomplete_types.hpp>
#include "incomplete_types-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T>
inline void Ptr_builder(Data_Type_T& klass)
{
  klass.define_attr("ptr", &Outer::Inner::Ptr<T>::ptr);
};

template<typename Data_Type_T, typename T>
inline void Deleter_builder(Data_Type_T& klass)
{
  klass.template define_method<void(Outer::Inner::Deleter<T>::*)(T*) const>("call", &Outer::Inner::Deleter<T>::operator(),
      std::conditional_t<std::is_fundamental_v<T>, ArgBuffer, Arg>("obj"));
};

