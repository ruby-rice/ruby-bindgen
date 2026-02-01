#include <constructors.hpp>
#include "constructors-rb.hpp"

using namespace Rice;

#include "constructors-rb.ipp"

void Init_Constructors()
{
  Rice::Data_Type<ImplicitConstructor> rb_cImplicitConstructor = define_class<ImplicitConstructor>("ImplicitConstructor").
    define_constructor(Constructor<ImplicitConstructor>());

  Rice::Data_Type<DefaultConstructor> rb_cDefaultConstructor = define_class<DefaultConstructor>("DefaultConstructor").
    define_constructor(Constructor<DefaultConstructor>());

  Rice::Data_Type<DeleteConstructor> rb_cDeleteConstructor = define_class<DeleteConstructor>("DeleteConstructor");

  Rice::Data_Type<OverloadedConstructors> rb_cOverloadedConstructors = define_class<OverloadedConstructors>("OverloadedConstructors").
    define_constructor(Constructor<OverloadedConstructors>()).
    define_constructor(Constructor<OverloadedConstructors, int>(),
      Arg("a"));

  Rice::Data_Type<CopyMoveConstructors> rb_cCopyMoveConstructors = define_class<CopyMoveConstructors>("CopyMoveConstructors").
    define_constructor(Constructor<CopyMoveConstructors>()).
    define_constructor(Constructor<CopyMoveConstructors, const CopyMoveConstructors&>(),
      Arg("other"));

  Rice::Data_Type<TemplateConstructor<int>> rb_cTemplateConstructorInt = TemplateConstructor_instantiate<int>(Rice::Module(rb_cObject), "TemplateConstructorInt");
}