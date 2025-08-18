#include <enum.hpp>
#include "enum-rb.hpp"

using namespace Rice;

Rice::Class rb_cMyNamespaceMyClass;



void Init_Enum()
{
  Enum<Color> rb_cColor = define_enum<Color>("Color").
    define_value("RED", Color::RED).
    define_value("BLACK", Color::BLACK).
    define_value("GREEN", Color::GREEN);
  
  Module rb_mAnonymous = define_module("Anonymous");
  
  Enum<::Language> rb_cAnonymousLanguage = define_enum_under<::Language>("Language", rb_mAnonymous).
    define_value("Ruby", ::Language::Ruby).
    define_value("CPP", ::Language::CPP).
    define_value("JavaScript", ::Language::JavaScript);
  
  Module rb_mMyNamespace = define_module("MyNamespace");
  
  Enum<MyNamespace::Season> rb_cMyNamespaceSeason = define_enum_under<MyNamespace::Season>("Season", rb_mMyNamespace).
    define_value("Spring", MyNamespace::Season::Spring).
    define_value("Summer", MyNamespace::Season::Summer).
    define_value("Fall", MyNamespace::Season::Fall).
    define_value("Winter", MyNamespace::Season::Winter);
  
  rb_cMyNamespaceMyClass = define_class_under<MyNamespace::MyClass>(rb_mMyNamespace, "MyClass").
    define_constructor(Constructor<MyNamespace::MyClass>()).
    define_constant("SOME_CONSTANT", MyNamespace::MyClass::SOME_CONSTANT);
  
  Enum<MyNamespace::MyClass::EmbeddedEnum> rb_cMyNamespaceMyClassEmbeddedEnum = define_enum_under<MyNamespace::MyClass::EmbeddedEnum>("EmbeddedEnum", rb_cMyNamespaceMyClass).
    define_value("Value1", MyNamespace::MyClass::EmbeddedEnum::Value1).
    define_value("Value2", MyNamespace::MyClass::EmbeddedEnum::Value2);
  
  rb_cMyNamespaceMyClass.define_constant("HACKED_CLASS_CONSTANT_1", (int)MyNamespace::MyClass::HACKED_CLASS_CONSTANT_1);
  rb_cMyNamespaceMyClass.define_constant("HACKED_CLASS_CONSTANT_2", (int)MyNamespace::MyClass::HACKED_CLASS_CONSTANT_2);

}