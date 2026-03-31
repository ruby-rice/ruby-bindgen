#include "opaque_namespace_handle.hpp"

namespace Tests
{
  class OpaqueNamespaceConsumer
  {
  public:
    OpaqueNamespaceConsumer();
    OpaqueNamespaceConsumer(const Render::Handle& handle);

    const Render::Handle& inHandle() const;
    Render::Handle outHandle() const;
    Render::Handle& outHandleRef();
    void setHandle(const Render::Handle& handle);

    int value() const;
  };
}
