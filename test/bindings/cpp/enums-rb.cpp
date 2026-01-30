#include <enums.hpp>
#include "enums-rb.hpp"

using namespace Rice;

void Init_Enums()
{
  Enum<Color> rb_cColor = define_enum<Color>("Color").
    define_value("RED", Color::RED).
    define_value("BLACK", Color::BLACK).
    define_value("GREEN", Color::GREEN);

  Module rb_mMyNamespace = define_module("MyNamespace");

  Enum<MyNamespace::Season> rb_cMyNamespaceSeason = define_enum_under<MyNamespace::Season>("Season", rb_mMyNamespace).
    define_value("Spring", MyNamespace::Season::Spring).
    define_value("Summer", MyNamespace::Season::Summer).
    define_value("Fall", MyNamespace::Season::Fall).
    define_value("Winter", MyNamespace::Season::Winter);

  Rice::Data_Type<MyNamespace::MyClass> rb_cMyNamespaceMyClass = define_class_under<MyNamespace::MyClass>(rb_mMyNamespace, "MyClass").
    define_constructor(Constructor<MyNamespace::MyClass>()).
    define_constant("SOME_CONSTANT", MyNamespace::MyClass::SOME_CONSTANT);

  Enum<MyNamespace::MyClass::EmbeddedEnum> rb_cMyNamespaceMyClassEmbeddedEnum = define_enum_under<MyNamespace::MyClass::EmbeddedEnum>("EmbeddedEnum", rb_cMyNamespaceMyClass).
    define_value("Value1", MyNamespace::MyClass::EmbeddedEnum::Value1).
    define_value("Value2", MyNamespace::MyClass::EmbeddedEnum::Value2);

  rb_cMyNamespaceMyClass.define_constant("HACKED_CLASS_CONSTANT_1", (int)MyNamespace::MyClass::HACKED_CLASS_CONSTANT_1);
  rb_cMyNamespaceMyClass.define_constant("HACKED_CLASS_CONSTANT_2", (int)MyNamespace::MyClass::HACKED_CLASS_CONSTANT_2);

  Rice::Data_Type<MyNamespace::Buffer> rb_cMyNamespaceBuffer = define_class_under<MyNamespace::Buffer>(rb_mMyNamespace, "Buffer").
    define_constructor(Constructor<MyNamespace::Buffer>()).
    define_method<void(MyNamespace::Buffer::*)(int, int, MyNamespace::Buffer::Target)>("create", &MyNamespace::Buffer::create,
      Arg("rows"), Arg("cols"), Arg("target") = static_cast<MyNamespace::Buffer::Target>(MyNamespace::Buffer::Target::ARRAY_BUFFER)).
    define_method<void(MyNamespace::Buffer::*)(MyNamespace::Buffer::Target)>("bind", &MyNamespace::Buffer::bind,
      Arg("target") = static_cast<MyNamespace::Buffer::Target>(MyNamespace::Buffer::Target::ARRAY_BUFFER));

  Enum<MyNamespace::Buffer::Target> rb_cMyNamespaceBufferTarget = define_enum_under<MyNamespace::Buffer::Target>("Target", rb_cMyNamespaceBuffer).
    define_value("ARRAY_BUFFER", MyNamespace::Buffer::Target::ARRAY_BUFFER).
    define_value("ELEMENT_ARRAY_BUFFER", MyNamespace::Buffer::Target::ELEMENT_ARRAY_BUFFER);

  Enum<MyNamespace::DecompTypes> rb_cMyNamespaceDecompTypes = define_enum_under<MyNamespace::DecompTypes>("DecompTypes", rb_mMyNamespace).
    define_value("DECOMP_LU", MyNamespace::DecompTypes::DECOMP_LU).
    define_value("DECOMP_SVD", MyNamespace::DecompTypes::DECOMP_SVD).
    define_value("DECOMP_CHOLESKY", MyNamespace::DecompTypes::DECOMP_CHOLESKY);

  Rice::Data_Type<MyNamespace::Solver> rb_cMyNamespaceSolver = define_class_under<MyNamespace::Solver>(rb_mMyNamespace, "Solver").
    define_constructor(Constructor<MyNamespace::Solver>()).
    define_method<void(MyNamespace::Solver::*)(int)>("solve", &MyNamespace::Solver::solve,
      Arg("method") = static_cast<int>(MyNamespace::DECOMP_SVD));

  Enum<MyNamespace::Flags> rb_cMyNamespaceFlags = define_enum_under<MyNamespace::Flags>("Flags", rb_mMyNamespace).
    define_value("FLAG_NONE", MyNamespace::Flags::FLAG_NONE).
    define_value("FLAG_READ", MyNamespace::Flags::FLAG_READ).
    define_value("FLAG_WRITE", MyNamespace::Flags::FLAG_WRITE);

  rb_mMyNamespace.define_module_function<const char*(*)(MyNamespace::Season)>("season_name", &MyNamespace::seasonName,
    Arg("season"));
}