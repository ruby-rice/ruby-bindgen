#include "non_system_external_opaque.hpp"

namespace Tests
{
  class NonSystemIncompleteRefs
  {
  public:
    NonSystemIncompleteRefs();
    NonSystemIncompleteRefs(const External::LocalOpaque& opaque);

    const External::LocalOpaque& inOpaque() const;
    External::LocalOpaque& outOpaque();
    void setOpaque(const External::LocalOpaque& opaque);

    int& valueRef();
    const int& valueConstRef() const;

    int value;
  };
}
