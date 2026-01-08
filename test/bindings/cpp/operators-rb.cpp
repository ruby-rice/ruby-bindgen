#include <operators.hpp>
#include "operators-rb.hpp"

using namespace Rice;

Rice::Class rb_cConvTarget;
Rice::Class rb_cDataPtrFloat;
Rice::Class rb_cDataPtrInt;
Rice::Class rb_cFileWriter;
Rice::Class rb_cMatrix;
Rice::Class rb_cNamespacedConversion;
Rice::Class rb_cOperators;
Rice::Class rb_cPrintable;

template<typename Data_Type_T, typename T>
inline void DataPtr_builder(Data_Type_T& klass)
{
  klass.define_attr("data", &DataPtr<T>::data).
    define_constructor(Constructor<DataPtr<T>>()).
    define_constructor(Constructor<DataPtr<T>, T*>(),
      Arg("ptr")).
    define_method("to_ptr", [](DataPtr<T>& self) -> T*
    {
      return self;
    }).
    define_method("to_const_ptr", [](const DataPtr<T>& self) -> const T*
    {
      return self;
    });
};
void Init_Operators()
{
  rb_cOperators = define_class<Operators>("Operators").
    define_attr("value", &Operators::value).
    define_constructor(Constructor<Operators>()).
    define_constructor(Constructor<Operators, int>(),
      Arg("v")).
    define_method("+", &Operators::operator+,
      Arg("other")).
    define_method("-", &Operators::operator-,
      Arg("other")).
    define_method<Operators(Operators::*)(const Operators&) const>("*", &Operators::operator*,
      Arg("other")).
    define_method("/", &Operators::operator/,
      Arg("other")).
    define_method("%", &Operators::operator%,
      Arg("other")).
    define_method("assign", &Operators::operator=,
      Arg("other")).
    define_method("assign_plus", &Operators::operator+=,
      Arg("other")).
    define_method("assign_minus", &Operators::operator-=,
      Arg("other")).
    define_method("assign_multiply", &Operators::operator*=,
      Arg("other")).
    define_method("assign_divide", &Operators::operator/=,
      Arg("other")).
    define_method("assign_modulus", &Operators::operator%=,
      Arg("other")).
    define_method("&", &Operators::operator&,
      Arg("other")).
    define_method("|", &Operators::operator|,
      Arg("other")).
    define_method("^", &Operators::operator^,
      Arg("other")).
    define_method("~", &Operators::operator~).
    define_method("<<", &Operators::operator<<,
      Arg("shift")).
    define_method(">>", &Operators::operator>>,
      Arg("shift")).
    define_method("assign_and", &Operators::operator&=,
      Arg("other")).
    define_method("assign_or", &Operators::operator|=,
      Arg("other")).
    define_method("assign_xor", &Operators::operator^=,
      Arg("other")).
    define_method("assign_left_shift", &Operators::operator<<=,
      Arg("shift")).
    define_method("assign_right_shift", &Operators::operator>>=,
      Arg("shift")).
    define_method("==", &Operators::operator==,
      Arg("other")).
    define_method("!=", &Operators::operator!=,
      Arg("other")).
    define_method("<", &Operators::operator<,
      Arg("other")).
    define_method(">", &Operators::operator>,
      Arg("other")).
    define_method("<=", &Operators::operator<=,
      Arg("other")).
    define_method(">=", &Operators::operator>=,
      Arg("other")).
    define_method("!", &Operators::operator!).
    define_method("logical_and", &Operators::operator&&,
      Arg("other")).
    define_method("logical_or", &Operators::operator||,
      Arg("other")).
    define_method<Operators&(Operators::*)()>("increment_pre", &Operators::operator++).
    define_method<Operators(Operators::*)(int)>("increment", &Operators::operator++,
      Arg("")).
    define_method<Operators&(Operators::*)()>("decrement_pre", &Operators::operator--).
    define_method<Operators(Operators::*)(int)>("decrement", &Operators::operator--,
      Arg("")).
    define_method<int&(Operators::*)(int)>("[]", &Operators::operator[],
      Arg("index")).
    define_method("[]=", [](Operators&self, int index, int & value)
    {
        self[index] = value;
    }).
    define_method<const int&(Operators::*)(int) const>("[]", &Operators::operator[],
      Arg("index")).
    define_method("call", &Operators::operator(),
      Arg("a"), Arg("b")).
    define_method<int(Operators::*)() const>("dereference", &Operators::operator*).
    define_method<Operators*(Operators::*)()>("arrow", &Operators::operator->).
    define_method<const Operators*(Operators::*)() const>("arrow", &Operators::operator->).
    define_method("to_i", [](const Operators& self) -> int
    {
      return self;
    }).
    define_method("to_f", [](const Operators& self) -> float
    {
      return self;
    }).
    define_method("to_bool", [](const Operators& self) -> bool
    {
      return self;
    });
  
  Module rb_mConv = define_module("Conv");
  
  rb_cConvTarget = define_class_under<conv::Target>(rb_mConv, "Target").
    define_attr("value", &conv::Target::value).
    define_constructor(Constructor<conv::Target>()).
    define_constructor(Constructor<conv::Target, int>(),
      Arg("v"));
  
  rb_cNamespacedConversion = define_class<NamespacedConversion>("NamespacedConversion").
    define_attr("value", &NamespacedConversion::value).
    define_constructor(Constructor<NamespacedConversion>()).
    define_constructor(Constructor<NamespacedConversion, int>(),
      Arg("v")).
    define_method("to_target", [](const NamespacedConversion& self) -> conv::Target
    {
      return self;
    }).
    define_method("to_target", [](NamespacedConversion& self) -> conv::Target&
    {
      return self;
    });
  
  rb_cDataPtrInt = define_class<DataPtr<int>>("DataPtrInt").
    define(&DataPtr_builder<Data_Type<DataPtr<int>>, int>);
  
  rb_cDataPtrFloat = define_class<DataPtr<float>>("DataPtrFloat").
    define(&DataPtr_builder<Data_Type<DataPtr<float>>, float>);
  
  rb_cMatrix = define_class<Matrix>("Matrix").
    define_attr("rows", &Matrix::rows).
    define_attr("cols", &Matrix::cols).
    define_constructor(Constructor<Matrix>()).
    define_constructor(Constructor<Matrix, int, int>(),
      Arg("r"), Arg("c"));
  
  rb_cMatrix.define_method("assign_plus", [](Matrix& self, const Matrix& other) -> Matrix&
  {
    return self += other;
  });
  
  rb_cMatrix.define_method("assign_minus", [](Matrix& self, const Matrix& other) -> Matrix&
  {
    return self -= other;
  });
  
  rb_cMatrix.define_method("assign_multiply", [](Matrix& self, double other) -> Matrix&
  {
    return self *= other;
  });
  
  rb_cPrintable = define_class<Printable>("Printable").
    define_attr("name", &Printable::name).
    define_attr("value", &Printable::value).
    define_constructor(Constructor<Printable>()).
    define_constructor(Constructor<Printable, const std::string&, int>(),
      Arg("n"), Arg("v"));
  
  rb_cPrintable.define_method("inspect", [](const Printable& self) -> std::string
  {
    std::ostringstream stream;
    stream << self;
    return stream.str();
  });
  
  rb_cFileWriter = define_class<FileWriter>("FileWriter").
    define_constructor(Constructor<FileWriter>()).
    define_method("open?", &FileWriter::isOpen);
  
  rb_cFileWriter.define_method("<<", [](FileWriter& self, const std::string& other) -> FileWriter&
  {
    return self << other;
  });
  
  rb_cFileWriter.define_method("<<", [](FileWriter& self, int other) -> FileWriter&
  {
    return self << other;
  });
  
  rb_cFileWriter.define_method("<<", [](FileWriter& self, const Printable& other) -> FileWriter&
  {
    return self << other;
  });

}