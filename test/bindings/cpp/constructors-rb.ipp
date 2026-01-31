#include <constructors.hpp>
#include "constructors-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T>
inline void TemplateConstructor_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<TemplateConstructor<T>>()).
    define_constructor(Constructor<TemplateConstructor<T>, T>(),
      Arg("value"));
};

