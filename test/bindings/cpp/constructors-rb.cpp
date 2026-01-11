#include <constructors.hpp>
#include "constructors-rb.hpp"

using namespace Rice;

Rice::Data_Type<CopyMoveConstructors> rb_cCopyMoveConstructors;
Rice::Data_Type<DefaultConstructor> rb_cDefaultConstructor;
Rice::Data_Type<DeleteConstructor> rb_cDeleteConstructor;
Rice::Data_Type<ImplicitConstructor> rb_cImplicitConstructor;
Rice::Data_Type<OverloadedConstructors> rb_cOverloadedConstructors;
Rice::Data_Type<TemplateConstructor<int>> rb_cTemplateConstructorInt;

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