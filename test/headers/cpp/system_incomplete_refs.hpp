#include <external_opaque.hpp>

namespace Tests
{
  class SystemIncompleteRefs
  {
  public:
    SystemIncompleteRefs();
    SystemIncompleteRefs(const External::Opaque& opaque);

    const External::Opaque& inOpaque() const;
    External::Opaque& outOpaque();
    void setOpaque(const External::Opaque& opaque);

    int& valueRef();
    const int& valueConstRef() const;

    int value;
  };
}
