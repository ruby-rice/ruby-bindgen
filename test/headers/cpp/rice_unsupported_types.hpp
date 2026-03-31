#include <cstddef>
#include <functional>
#include <memory>
#include <vector>

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

  class MoveFriendly
  {
  public:
    MoveFriendly() = default;
    MoveFriendly(const MoveFriendly&) = default;
    MoveFriendly(MoveFriendly&&) = default;

    MoveFriendly& operator=(const MoveFriendly&) = default;
    MoveFriendly& operator=(MoveFriendly&&) = default;

    static void consume(MoveFriendly&& value);
  };

  class VectorSink
  {
  public:
    VectorSink();
    VectorSink(std::vector<int>&& values);

    void setValues(std::vector<int>&& values);
  };
}
