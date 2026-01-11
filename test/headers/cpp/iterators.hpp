#include <vector>
#include <iterator>
#include <cstddef>

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

  // Simple iterator types for testing - must be fully functional for Rice
  class PixelIterator {
  public:
    using value_type = Pixel;
    using reference = Pixel&;
    using pointer = Pixel*;
    using difference_type = std::ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;

    PixelIterator() : ptr_(nullptr) {}
    explicit PixelIterator(pointer p) : ptr_(p) {}
    reference operator*() const { return *ptr_; }
    PixelIterator& operator++() { ++ptr_; return *this; }
    bool operator!=(const PixelIterator& other) const { return ptr_ != other.ptr_; }
  private:
    pointer ptr_;
  };

  class ConstPixelIterator {
  public:
    using value_type = Pixel;
    using reference = const Pixel&;
    using pointer = const Pixel*;
    using difference_type = std::ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;

    ConstPixelIterator() : ptr_(nullptr) {}
    explicit ConstPixelIterator(pointer p) : ptr_(p) {}
    reference operator*() const { return *ptr_; }
    ConstPixelIterator& operator++() { ++ptr_; return *this; }
    bool operator!=(const ConstPixelIterator& other) const { return ptr_ != other.ptr_; }
  private:
    pointer ptr_;
  };

  class ReversePixelIterator {
  public:
    using value_type = Pixel;
    using reference = Pixel&;
    using pointer = Pixel*;
    using difference_type = std::ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;

    ReversePixelIterator() : ptr_(nullptr) {}
    explicit ReversePixelIterator(pointer p) : ptr_(p) {}
    reference operator*() const { return *ptr_; }
    ReversePixelIterator& operator++() { --ptr_; return *this; }
    bool operator!=(const ReversePixelIterator& other) const { return ptr_ != other.ptr_; }
  private:
    pointer ptr_;
  };

  class ConstReversePixelIterator {
  public:
    using value_type = Pixel;
    using reference = const Pixel&;
    using pointer = const Pixel*;
    using difference_type = std::ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;

    ConstReversePixelIterator() : ptr_(nullptr) {}
    explicit ConstReversePixelIterator(pointer p) : ptr_(p) {}
    reference operator*() const { return *ptr_; }
    ConstReversePixelIterator& operator++() { --ptr_; return *this; }
    bool operator!=(const ConstReversePixelIterator& other) const { return ptr_ != other.ptr_; }
  private:
    pointer ptr_;
  };

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
