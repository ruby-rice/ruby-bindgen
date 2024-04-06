#include <constructors.hpp>
#include "constructors-rb.hpp"

using namespace Rice;

Rice::Class rb_cDefaultConstructor;
Rice::Class rb_cDeleteConstructor;
Rice::Class rb_cImplicitConstructor;
Rice::Class rb_cOverloadedConstructors;

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

}