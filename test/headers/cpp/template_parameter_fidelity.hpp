#pragma once

namespace Support {
struct Net
{
};
}

namespace Tests {
template<typename Net>
class TemplateParamShadow
{
public:
  TemplateParamShadow& assign(const Net& value);
};

template<typename... Ts>
class ParameterPackHolder
{
public:
  ParameterPackHolder();
  ParameterPackHolder(const ParameterPackHolder<Ts...>& other);
  void swap(ParameterPackHolder<Ts...>& rhs);
};
}
