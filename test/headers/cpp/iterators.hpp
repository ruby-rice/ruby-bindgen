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

  // Iterator WITHOUT proper std::iterator_traits - like cv::ImageCollection::iterator
  // This will cause compile errors with Rice unless std::iterator_traits is specialized
  class IncompleteIterator {
  public:
    IncompleteIterator() : ptr_(nullptr) {}
    explicit IncompleteIterator(Pixel* p) : ptr_(p) {}
    Pixel& operator*() const { return *ptr_; }
    Pixel* operator->() const { return ptr_; }
    IncompleteIterator& operator++() { ++ptr_; return *this; }
    IncompleteIterator operator++(int) { IncompleteIterator tmp = *this; ++ptr_; return tmp; }
    friend bool operator==(const IncompleteIterator& a, const IncompleteIterator& b) { return a.ptr_ == b.ptr_; }
    friend bool operator!=(const IncompleteIterator& a, const IncompleteIterator& b) { return a.ptr_ != b.ptr_; }
  private:
    Pixel* ptr_;
    // NOTE: Missing value_type, reference, pointer, difference_type, iterator_category
  };

  // Container using the incomplete iterator
  class IncompleteBitmap
  {
  public:
    IncompleteBitmap();
    IncompleteIterator begin();
    IncompleteIterator end();
  };

  // Test class template with nested iterator typedefs
  // Similar to cv::Mat_<_Tp> which has iterator/const_iterator typedefs
  // and returns std::reverse_iterator<iterator> from rbegin/rend
  template<typename T>
  class TemplateContainer
  {
  public:
    typedef T* iterator;
    typedef const T* const_iterator;

    TemplateContainer() : data_(nullptr), size_(0) {}

    iterator begin() { return data_; }
    iterator end() { return data_ + size_; }
    const_iterator begin() const { return data_; }
    const_iterator end() const { return data_ + size_; }

    // Reverse iterators using std::reverse_iterator with nested typedef
    // This tests that "iterator" gets qualified to "iter::TemplateContainer<T>::iterator"
    std::reverse_iterator<iterator> rbegin() { return std::reverse_iterator<iterator>(end()); }
    std::reverse_iterator<iterator> rend() { return std::reverse_iterator<iterator>(begin()); }
    std::reverse_iterator<const_iterator> rbegin() const { return std::reverse_iterator<const_iterator>(end()); }
    std::reverse_iterator<const_iterator> rend() const { return std::reverse_iterator<const_iterator>(begin()); }

  private:
    T* data_;
    size_t size_;
  };

  typedef TemplateContainer<Pixel> PixelContainer;
}
