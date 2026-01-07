#include <incomplete_types.hpp>
#include "incomplete_types-rb.hpp"

using namespace Rice;

Rice::Class rb_cOuterInnerPimplClass;
Rice::Class rb_cOuterInnerPimplClassWithPublicField;

void Init_IncompleteTypes()
{
  Module rb_mOuter = define_module("Outer");
  
  Module rb_mOuterInner = define_module_under(rb_mOuter, "Inner");
  
  rb_cOuterInnerPimplClass = define_class_under<Outer::Inner::PimplClass>(rb_mOuterInner, "PimplClass").
    define_constructor(Constructor<Outer::Inner::PimplClass>()).
    define_method("empty?", &Outer::Inner::PimplClass::empty);
  
  
  rb_cOuterInnerPimplClassWithPublicField = define_class_under<Outer::Inner::PimplClassWithPublicField>(rb_mOuterInner, "PimplClassWithPublicField").
    define_constructor(Constructor<Outer::Inner::PimplClassWithPublicField>()).
    define_attr("value", &Outer::Inner::PimplClassWithPublicField::value);
  

}