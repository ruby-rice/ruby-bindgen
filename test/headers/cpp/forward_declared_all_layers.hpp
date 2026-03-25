#include "forward_declared_classes.hpp"

namespace ForwardDeclaredClasses
{
  class ActivationLayer : public Layer
  {
  public:
    ActivationLayer() = default;

    bool forward() const
    {
      return true;
    }
  };
}
