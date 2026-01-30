#include <cross_file_derived.hpp>
#include "cross_file_derived-rb.hpp"

using namespace Rice;

template<typename Data_Type_T, typename T, int N>
inline void DerivedVector_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<CrossFile::DerivedVector<T, N>>()).
    template define_method<T(CrossFile::DerivedVector<T, N>::*)(const CrossFile::DerivedVector<T, N>&) const>("dot", &CrossFile::DerivedVector<T, N>::dot,
      Arg("other"));
};

void Init_CrossFileDerived()
{
  Module rb_mCrossFile = define_module("CrossFile");

  Rice::Data_Type<CrossFile::BaseMatrix<double, 4>> rb_cBaseMatrix4d = define_class_under<CrossFile::BaseMatrix<double, 4>>(rb_mCrossFile, "BaseMatrix4d").
    define(&BaseMatrix_builder<Data_Type<CrossFile::BaseMatrix<double, 4>>, double, 4>);
  Rice::Data_Type<CrossFile::DerivedVector<double, 4>> rb_cDerivedVector4d = define_class_under<CrossFile::DerivedVector<double, 4>, CrossFile::BaseMatrix<double, 4>>(rb_mCrossFile, "DerivedVector4d").
    define(&DerivedVector_builder<Data_Type<CrossFile::DerivedVector<double, 4>>, double, 4>);

  Rice::Data_Type<CrossFile::SimpleRange> rb_cCrossFileSimpleRange = define_class_under<CrossFile::SimpleRange>(rb_mCrossFile, "SimpleRange").
    define_attr("start", &CrossFile::SimpleRange::start).
    define_attr("end", &CrossFile::SimpleRange::end).
    define_constructor(Constructor<CrossFile::SimpleRange>()).
    define_constructor(Constructor<CrossFile::SimpleRange, int, int>(),
      Arg("s"), Arg("e"));

  rb_cBaseMatrix4d.
    define_method("*", [](const CrossFile::BaseMatrix4d& self, double other) -> CrossFile::BaseMatrix4d
  {
    return self * other;
  });
  
  rb_cCrossFileSimpleRange.
    define_method("==", [](const CrossFile::SimpleRange& self, const CrossFile::SimpleRange& other) -> bool
  {
    return self == other;
  });
}