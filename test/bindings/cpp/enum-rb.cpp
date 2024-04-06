#include <enum.hpp>
#include "enum-rb.hpp"

using namespace Rice;



extern "C"
void Init_Enum()
{
  Enum<Color> rb_cColor = define_enum<Color>("Color", rb_cObject).
    define_value("RED", Color::RED).
    define_value("BLACK", Color::BLACK).
    define_value("GREEN", Color::GREEN);
  
  Module rb_m = define_module("");
  
  
  Module rb_mMyNamespace = define_module("MyNamespace");
  
  Enum<MyNamespace::Season> rb_cMyNamespaceSeason = define_enum<MyNamespace::Season>("Season", rb_mMyNamespace).
    define_value("Spring", MyNamespace::Season::Spring).
    define_value("Summer", MyNamespace::Season::Summer).
    define_value("Fall", MyNamespace::Season::Fall).
    define_value("Winter", MyNamespace::Season::Winter);

}