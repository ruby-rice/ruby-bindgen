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

template<typename... Ts>
class ParameterPackAliasHolder
{
public:
  using StorageT = ParameterPackHolder<Ts...>;
  using Map = StorageT;

  StorageT& storage();
  void setStorage(StorageT& value);
  const Map& getStorage() const;
};
}
