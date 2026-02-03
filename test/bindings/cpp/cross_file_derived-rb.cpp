#include <cross_file_derived.hpp>
#include "cross_file_derived-rb.hpp"

using namespace Rice;

#include "cross_file_derived-rb.ipp"

void Init_CrossFileDerived()
{
  Module rb_mCrossFile = define_module("CrossFile");

  Rice::Data_Type<CrossFile::BaseMatrix<double, 4>> rb_cBaseMatrix4d = BaseMatrix_instantiate<double, 4>(rb_mCrossFile, "BaseMatrix4d");
  Rice::Data_Type<CrossFile::DerivedVector<double, 4>> rb_cDerivedVector4d = DerivedVector_instantiate<double, 4>(rb_mCrossFile, "DerivedVector4d");

  Rice::Data_Type<CrossFile::SimpleRange> rb_cCrossFileSimpleRange = define_class_under<CrossFile::SimpleRange>(rb_mCrossFile, "SimpleRange").
    define_attr("start", &CrossFile::SimpleRange::start).
    define_attr("end", &CrossFile::SimpleRange::end).
    define_constructor(Constructor<CrossFile::SimpleRange>()).
    define_constructor(Constructor<CrossFile::SimpleRange, int, int>(),
      Arg("s"), Arg("e"));

  rb_cBaseMatrix4d.
    define_method("*", [](const CrossFile::BaseMatrix4d& self, double other) -> CrossFile::BaseMatrix4d {
    return self * other;
  });
  
  rb_cCrossFileSimpleRange.
    define_method("==", [](const CrossFile::SimpleRange& self, const CrossFile::SimpleRange& other) -> bool {
    return self == other;
  });
  
  Data_Type<CrossFile::Point2d>().
    define_method("+", [](const CrossFile::Point2d& self, double other) -> CrossFile::Point2d {
    return self + other;
  });
}