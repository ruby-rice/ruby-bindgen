#include "operators-rb.ipp"

void Init_Operators()
{
  Rice::Data_Type<Operators> rb_cOperators = define_class<Operators>("Operators").
    define_attr("value", &Operators::value).
    define_constructor(Constructor<Operators>()).
    define_constructor(Constructor<Operators, int>(),
      Arg("v")).
    define_method<Operators(Operators::*)(const Operators&) const>("+", &Operators::operator+,
      Arg("other")).
    define_method<Operators(Operators::*)(const Operators&) const>("-", &Operators::operator-,
      Arg("other")).
    define_method<Operators(Operators::*)(const Operators&) const>("*", &Operators::operator*,
      Arg("other")).
    define_method<Operators(Operators::*)(const Operators&) const>("/", &Operators::operator/,
      Arg("other")).
    define_method<Operators(Operators::*)(const Operators&) const>("%", &Operators::operator%,
      Arg("other")).
    define_method<Operators&(Operators::*)(const Operators&)>("assign", &Operators::operator=,
      Arg("other")).
    define_method<Operators&(Operators::*)(const Operators&)>("assign_plus", &Operators::operator+=,
      Arg("other")).
    define_method<Operators&(Operators::*)(const Operators&)>("assign_minus", &Operators::operator-=,
      Arg("other")).
    define_method<Operators&(Operators::*)(const Operators&)>("assign_multiply", &Operators::operator*=,
      Arg("other")).
    define_method<Operators&(Operators::*)(const Operators&)>("assign_divide", &Operators::operator/=,
      Arg("other")).
    define_method<Operators&(Operators::*)(const Operators&)>("assign_modulus", &Operators::operator%=,
      Arg("other")).
    define_method<Operators(Operators::*)(const Operators&) const>("&", &Operators::operator&,
      Arg("other")).
    define_method<Operators(Operators::*)(const Operators&) const>("|", &Operators::operator|,
      Arg("other")).
    define_method<Operators(Operators::*)(const Operators&) const>("^", &Operators::operator^,
      Arg("other")).
    define_method<Operators(Operators::*)() const>("~", &Operators::operator~).
    define_method<Operators(Operators::*)(int) const>("<<", &Operators::operator<<,
      Arg("shift")).
    define_method<Operators(Operators::*)(int) const>(">>", &Operators::operator>>,
      Arg("shift")).
    define_method<Operators&(Operators::*)(const Operators&)>("assign_and", &Operators::operator&=,
      Arg("other")).
    define_method<Operators&(Operators::*)(const Operators&)>("assign_or", &Operators::operator|=,
      Arg("other")).
    define_method<Operators&(Operators::*)(const Operators&)>("assign_xor", &Operators::operator^=,
      Arg("other")).
    define_method<Operators&(Operators::*)(int)>("assign_left_shift", &Operators::operator<<=,
      Arg("shift")).
    define_method<Operators&(Operators::*)(int)>("assign_right_shift", &Operators::operator>>=,
      Arg("shift")).
    define_method<bool(Operators::*)(const Operators&) const>("==", &Operators::operator==,
      Arg("other")).
    define_method<bool(Operators::*)(const Operators&) const>("!=", &Operators::operator!=,
      Arg("other")).
    define_method<bool(Operators::*)(const Operators&) const>("<", &Operators::operator<,
      Arg("other")).
    define_method<bool(Operators::*)(const Operators&) const>(">", &Operators::operator>,
      Arg("other")).
    define_method<bool(Operators::*)(const Operators&) const>("<=", &Operators::operator<=,
      Arg("other")).
    define_method<bool(Operators::*)(const Operators&) const>(">=", &Operators::operator>=,
      Arg("other")).
    define_method<bool(Operators::*)() const>("!", &Operators::operator!).
    define_method<bool(Operators::*)(const Operators&) const>("logical_and", &Operators::operator&&,
      Arg("other")).
    define_method<bool(Operators::*)(const Operators&) const>("logical_or", &Operators::operator||,
      Arg("other")).
    define_method<Operators&(Operators::*)()>("increment", &Operators::operator++).
    define_method<Operators(Operators::*)(int)>("increment_post", &Operators::operator++,
      Arg("arg_0")).
    define_method<Operators&(Operators::*)()>("decrement", &Operators::operator--).
    define_method<Operators(Operators::*)(int)>("decrement_post", &Operators::operator--,
      Arg("arg_0")).
    define_method<int&(Operators::*)(int)>("[]", &Operators::operator[],
      Arg("index")).
    define_method("[]=", [](Operators&self, int index, int & value)
    {
        self[index] = value;
    }).
    define_method<const int&(Operators::*)(int) const>("[]", &Operators::operator[],
      Arg("index")).
    define_method<int(Operators::*)(int, int)>("call", &Operators::operator(),
      Arg("a"), Arg("b")).
    define_method<int(Operators::*)() const>("dereference", &Operators::operator*).
    define_method<Operators*(Operators::*)()>("arrow", &Operators::operator->).
    define_method<const Operators*(Operators::*)() const>("arrow", &Operators::operator->).
    define_method("to_i", [](const Operators& self) -> int
    {
      return self;
    }).
    define_method("to_f32", [](const Operators& self) -> float
    {
      return self;
    }).
    define_method("to_bool", [](const Operators& self) -> bool
    {
      return self;
    });

  Module rb_mConv = define_module("Conv");

  Rice::Data_Type<conv::Target> rb_cConvTarget = define_class_under<conv::Target>(rb_mConv, "Target").
    define_attr("value", &conv::Target::value).
    define_constructor(Constructor<conv::Target>()).
    define_constructor(Constructor<conv::Target, int>(),
      Arg("v"));

  Rice::Data_Type<NamespacedConversion> rb_cNamespacedConversion = define_class<NamespacedConversion>("NamespacedConversion").
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

  Rice::Data_Type<DataPtr<int>> rb_cDataPtrInt = define_class<DataPtr<int>>("DataPtrInt").
    define(&DataPtr_builder<Data_Type<DataPtr<int>>, int>);

  Rice::Data_Type<DataPtr<float>> rb_cDataPtrFloat = define_class<DataPtr<float>>("DataPtrFloat").
    define(&DataPtr_builder<Data_Type<DataPtr<float>>, float>);

  Rice::Data_Type<Matrix> rb_cMatrix = define_class<Matrix>("Matrix").
    define_attr("rows", &Matrix::rows).
    define_attr("cols", &Matrix::cols).
    define_constructor(Constructor<Matrix>()).
    define_constructor(Constructor<Matrix, int, int>(),
      Arg("r"), Arg("c"));

  Rice::Data_Type<Printable> rb_cPrintable = define_class<Printable>("Printable").
    define_attr("name", &Printable::name).
    define_attr("value", &Printable::value).
    define_constructor(Constructor<Printable>()).
    define_constructor(Constructor<Printable, const std::string&, int>(),
      Arg("n"), Arg("v"));

  Rice::Data_Type<FileWriter> rb_cFileWriter = define_class<FileWriter>("FileWriter").
    define_constructor(Constructor<FileWriter>()).
    define_method<bool(FileWriter::*)() const>("open?", &FileWriter::isOpen);

  Rice::Data_Type<AllConversions> rb_cAllConversions = define_class<AllConversions>("AllConversions").
    define_constructor(Constructor<AllConversions>()).
    define_method("to_i", [](const AllConversions& self) -> int
    {
      return self;
    }).
    define_method("to_l", [](const AllConversions& self) -> long
    {
      return self;
    }).
    define_method("to_i64", [](const AllConversions& self) -> long long
    {
      return self;
    }).
    define_method("to_i16", [](const AllConversions& self) -> short
    {
      return self;
    }).
    define_method("to_u", [](const AllConversions& self) -> unsigned int
    {
      return self;
    }).
    define_method("to_ul", [](const AllConversions& self) -> unsigned long
    {
      return self;
    }).
    define_method("to_u64", [](const AllConversions& self) -> unsigned long long
    {
      return self;
    }).
    define_method("to_u16", [](const AllConversions& self) -> unsigned short
    {
      return self;
    }).
    define_method("to_f32", [](const AllConversions& self) -> float
    {
      return self;
    }).
    define_method("to_f", [](const AllConversions& self) -> double
    {
      return self;
    }).
    define_method("to_ld", [](const AllConversions& self) -> long double
    {
      return self;
    }).
    define_method("to_bool", [](const AllConversions& self) -> bool
    {
      return self;
    }).
    define_method("to_s", [](const AllConversions& self) -> std::string
    {
      return self;
    });

  Rice::Data_Type<SizeTConversion> rb_cSizeTConversion = define_class<SizeTConversion>("SizeTConversion").
    define_attr("value", &SizeTConversion::value).
    define_constructor(Constructor<SizeTConversion>()).
    define_method("to_size", [](const SizeTConversion& self) -> size_t
    {
      return self;
    });

  rb_cMatrix.
    define_method("assign_plus", [](Matrix& self, const Matrix& other) -> Matrix&
  {
    self += other;
    return self;
  }).
    define_method("assign_minus", [](Matrix& self, const Matrix& other) -> Matrix&
  {
    self -= other;
    return self;
  }).
    define_method("assign_multiply", [](Matrix& self, double other) -> Matrix&
  {
    self *= other;
    return self;
  });
  
  rb_cPrintable.
    define_method("inspect", [](const Printable& self) -> std::string
  {
    std::ostringstream stream;
    stream << self;
    return stream.str();
  });
  
  rb_cFileWriter.
    define_method("<<", [](FileWriter& self, const std::string& other) -> FileWriter&
  {
    self << other;
    return self;
  }).
    define_method("<<", [](FileWriter& self, int other) -> FileWriter&
  {
    self << other;
    return self;
  }).
    define_method("<<", [](FileWriter& self, const Printable& other) -> FileWriter&
  {
    self << other;
    return self;
  });
}