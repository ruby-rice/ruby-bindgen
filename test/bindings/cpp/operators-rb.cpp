#include <operators.hpp>
#include "operators-rb.hpp"

using namespace Rice;

Rice::Class rb_cOperators;

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

}