#include <vector>

namespace Tests
{
  struct UnsupportedVectorValue
  {
    int value;
  };

  class UnsupportedVectorReturns
  {
  public:
    using Items = std::vector<UnsupportedVectorValue>;

    Items items() const;
    operator Items();
  };
}
