#pragma once

#include <vector>

namespace Tests {
template<typename Net>
struct PortCfg
{
  using In = std::vector<Net>;
  using Out = Net;
};

template<typename Net>
class Params
{
public:
  Params& cfgInputLayers(const typename PortCfg<Net>::In& layer_names);
  Params& cfgOutputLayers(const typename PortCfg<Net>::Out& layer_name);
};

template<typename T>
class Array
{
public:
  using HT = T;

  Array();
  explicit Array(const std::vector<Array::HT>& values);
};
}
