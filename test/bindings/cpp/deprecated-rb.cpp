#include <deprecated.hpp>
#include "deprecated-rb.hpp"

using namespace Rice;

Rice::Class rb_cOuterInnerMyClass;

void Init_Deprecated()
{
  Module rb_mOuter = define_module("Outer");
  
  Module rb_mOuterInner = define_module_under(rb_mOuter, "Inner");
  
  rb_mOuterInner.define_module_function("normal_function", &Outer::Inner::normalFunction);
  
  rb_cOuterInnerMyClass = define_class_under<Outer::Inner::MyClass>(rb_mOuterInner, "MyClass").
    define_constructor(Constructor<Outer::Inner::MyClass>()).
    define_method("new_method", &Outer::Inner::MyClass::newMethod);

}