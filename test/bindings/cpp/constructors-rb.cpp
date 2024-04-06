#include <constructors.hpp>
#include "constructors-rb.hpp"

using namespace Rice;



extern "C"
void Init_Constructors()
{
  Class rb_cImplicitConstructor = define_class<ImplicitConstructor>("ImplicitConstructor").
    define_constructor(Constructor<ImplicitConstructor>());
  
  Class rb_cDefaultConstructor = define_class<DefaultConstructor>("DefaultConstructor").
    define_constructor(Constructor<DefaultConstructor>());
  
  Class rb_cDeleteConstructor = define_class<DeleteConstructor>("DeleteConstructor");
  
  Class rb_cOverloadedConstructors = define_class<OverloadedConstructors>("OverloadedConstructors").
    define_constructor(Constructor<OverloadedConstructors>()).
    define_constructor(Constructor<OverloadedConstructors, int>());

}