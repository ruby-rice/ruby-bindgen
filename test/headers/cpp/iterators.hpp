#include <vector>

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

  // Simple iterator types for testing
  class PixelIterator {};
  class ConstPixelIterator {};
  class ReversePixelIterator {};
  class ConstReversePixelIterator {};

  // Test with simple custom iterator types
  class Bitmap
  {
  public:
    Bitmap();

    // Regular iterators
    PixelIterator begin() noexcept;
    PixelIterator end() noexcept;

    // Const iterators (method is const)
    ConstPixelIterator begin() const noexcept;
    ConstPixelIterator end() const noexcept;

    // Explicit const iterators (cbegin/cend)
    ConstPixelIterator cbegin() const noexcept;
    ConstPixelIterator cend() const noexcept;

    // Reverse iterators
    ReversePixelIterator rbegin() noexcept;
    ReversePixelIterator rend() noexcept;

    // Const reverse iterators (method is const)
    ConstReversePixelIterator rbegin() const noexcept;
    ConstReversePixelIterator rend() const noexcept;

    // Explicit const reverse iterators (crbegin/crend)
    ConstReversePixelIterator crbegin() const noexcept;
    ConstReversePixelIterator crend() const noexcept;
  };

  // Test with std::vector iterator types (like BitmapPlusPlus)
  class VectorBitmap
  {
  public:
    VectorBitmap();

    // Regular iterators
    std::vector<Pixel>::iterator begin() noexcept;
    std::vector<Pixel>::iterator end() noexcept;

    // Const iterators (method is const)
    std::vector<Pixel>::const_iterator begin() const noexcept;
    std::vector<Pixel>::const_iterator end() const noexcept;

    // Explicit const iterators (cbegin/cend)
    std::vector<Pixel>::const_iterator cbegin() const noexcept;
    std::vector<Pixel>::const_iterator cend() const noexcept;

    // Reverse iterators
    std::vector<Pixel>::reverse_iterator rbegin() noexcept;
    std::vector<Pixel>::reverse_iterator rend() noexcept;

    // Const reverse iterators (method is const)
    std::vector<Pixel>::const_reverse_iterator rbegin() const noexcept;
    std::vector<Pixel>::const_reverse_iterator rend() const noexcept;

    // Explicit const reverse iterators (crbegin/crend)
    std::vector<Pixel>::const_reverse_iterator crbegin() const noexcept;
    std::vector<Pixel>::const_reverse_iterator crend() const noexcept;

  private:
    std::vector<Pixel> m_pixels;
  };
}
