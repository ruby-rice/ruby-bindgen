// STL container iterator tests.
// These use std::vector/std::map iterators whose fully_qualified_name
// expands default template args (e.g., std::allocator<T>) on LLVM 21+.
// Kept separate because the compat shim (LLVM < 21) cannot expand defaults.

#include <vector>
#include <map>
#include <string>

namespace iter
{
  class Pixel
  {
  public:
    Pixel();
    Pixel(int r, int g, int b);

    int r;
    int g;
    int b;
  };

  // Typedef that should be qualified in iterator template arguments
  typedef std::string String;

  // A simple value type for the map
  class DictValue
  {
  public:
    DictValue();
    int value;
  };

  // Class with iterator returning std::map<String, DictValue>::const_iterator
  class Dict
  {
  public:
    Dict();
    std::map<String, DictValue>::const_iterator begin() const;
    std::map<String, DictValue>::const_iterator end() const;
  };

  // Test with std::vector iterator types
  class VectorBitmap
  {
  public:
    VectorBitmap();

    std::vector<Pixel>::iterator begin() noexcept;
    std::vector<Pixel>::iterator end() noexcept;

    std::vector<Pixel>::const_iterator begin() const noexcept;
    std::vector<Pixel>::const_iterator end() const noexcept;

    std::vector<Pixel>::reverse_iterator rbegin() noexcept;
    std::vector<Pixel>::reverse_iterator rend() noexcept;

    std::vector<Pixel>::const_reverse_iterator rbegin() const noexcept;
    std::vector<Pixel>::const_reverse_iterator rend() const noexcept;

  private:
    std::vector<Pixel> m_pixels;
  };
}
