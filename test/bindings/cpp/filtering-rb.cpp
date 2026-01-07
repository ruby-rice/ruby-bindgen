#include <filtering.hpp>
#include "filtering-rb.hpp"

using namespace Rice;

Rice::Class rb_cOuterMyClass;

void Init_Filtering()
{
  Module rb_mOuter = define_module("Outer");
  
  rb_mOuter.define_module_function("exported_function", &Outer::exportedFunction);
  
  rb_mOuter.define_module_function("normal_function", &Outer::normalFunction);
  
  rb_cOuterMyClass = define_class_under<Outer::MyClass>(rb_mOuter, "MyClass").
    define_constructor(Constructor<Outer::MyClass>()).
    define_method("new_method", &Outer::MyClass::newMethod);

}