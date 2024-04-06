#include <rice/rice.hpp>

Enum<Color> rb_cColor = define_enum<Color>("Color", rb_cObject).
  define_value("red", 0).
  define_value("black", 1).
  define_value("green", 2);

Module rb_m = define_module("");

Enum<Language> rb_cLanguage = define_enum<Language>("Language", rb_m).
  define_value("ruby", 0).
  define_value("cpp", 1).
  define_value("java_script", 2);

Module rb_mMyNamespace = define_module("MyNamespace");

Enum<Season> rb_cSeason = define_enum<Season>("Season", rb_mMyNamespace).
  define_value("spring", 0).
  define_value("summer", 1).
  define_value("fall", 2).
  define_value("winter", 7);