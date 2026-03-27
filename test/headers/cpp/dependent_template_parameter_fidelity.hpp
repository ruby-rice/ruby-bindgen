#pragma once

namespace Support {
struct Net
{
};
}

namespace Tests {
template<typename Net>
struct PortCfg
{
  using In = Net;
  using Out = Net;
};

template<typename Net>
class Params
{
public:
  Params& cfgInputLayers(const typename PortCfg<Net>::In& layer_names);
  Params& cfgOutputLayers(const typename PortCfg<Net>::Out& layer_name);
};
}
