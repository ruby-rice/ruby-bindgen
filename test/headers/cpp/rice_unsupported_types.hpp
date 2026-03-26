#include <cstddef>
#include <functional>
#include <memory>

namespace Tests
{
  class UnsupportedRiceTypes
  {
  public:
    class Priv;

    using Callback = std::function<void(UnsupportedRiceTypes&)>;
    using NestedCallback = std::function<void(std::size_t, std::function<void(UnsupportedRiceTypes&)>)>;

    UnsupportedRiceTypes();
    UnsupportedRiceTypes(const Callback& callback);
    UnsupportedRiceTypes(std::unique_ptr<Priv>&& priv);

    void setCallback(const Callback& callback);
    void setPriv(std::unique_ptr<Priv>&& priv);
    static void install(const NestedCallback& callback);
    static void notify(std::function<void()>&& callback);

    Priv& priv();
    const Priv& priv() const;

    Callback callback;
    NestedCallback nestedCallback;
    int value;
  };
}
