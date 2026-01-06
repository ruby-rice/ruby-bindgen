#include <constructors.hpp>
#include "constructors-rb.hpp"

using namespace Rice;

Rice::Class rb_cCopyMoveConstructors;
Rice::Class rb_cDefaultConstructor;
Rice::Class rb_cDeleteConstructor;
Rice::Class rb_cImplicitConstructor;
Rice::Class rb_cOverloadedConstructors;
Rice::Class rb_cTemplateConstructorInt;

template<typename Data_Type_T, typename T>
inline void TemplateConstructor_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<TemplateConstructor<T>>()).
    define_constructor(Constructor<TemplateConstructor<T>, T>(),
      Arg("value"));
};
void Init_Constructors()
{
  rb_cImplicitConstructor = define_class<ImplicitConstructor>("ImplicitConstructor").
    define_constructor(Constructor<ImplicitConstructor>());
  
  rb_cDefaultConstructor = define_class<DefaultConstructor>("DefaultConstructor").
    define_constructor(Constructor<DefaultConstructor>());
  
  rb_cDeleteConstructor = define_class<DeleteConstructor>("DeleteConstructor");
  
  rb_cOverloadedConstructors = define_class<OverloadedConstructors>("OverloadedConstructors").
    define_constructor(Constructor<OverloadedConstructors>()).
    define_constructor(Constructor<OverloadedConstructors, int>(),
      Arg("a"));
  
  rb_cCopyMoveConstructors = define_class<CopyMoveConstructors>("CopyMoveConstructors").
    define_constructor(Constructor<CopyMoveConstructors>()).
    define_constructor(Constructor<CopyMoveConstructors, const CopyMoveConstructors&>(),
      Arg("other"));
  
  rb_cTemplateConstructorInt = define_class<TemplateConstructor<int>>("TemplateConstructorInt").
    define(&TemplateConstructor_builder<Data_Type<TemplateConstructor<int>>, int>);

}