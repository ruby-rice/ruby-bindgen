#include <iterators.hpp>
#include "iterators-rb.hpp"

// Iterator traits specializations for iterators missing std::iterator_traits
namespace std
{
  template<>
  struct iterator_traits<iter::IncompleteIterator>
  {
    using iterator_category = forward_iterator_tag;
    using value_type = iter::Pixel;
    using difference_type = ptrdiff_t;
    using pointer = iter::Pixel*;
    using reference = iter::Pixel&;
  };
}

using namespace Rice;

template<typename Data_Type_T, typename T>
inline void TemplateContainer_builder(Data_Type_T& klass)
{
  klass.define_constructor(Constructor<iter::TemplateContainer<T>>()).
    template define_iterator<typename iter::TemplateContainer<T>::iterator(iter::TemplateContainer<T>::*)()>(&iter::TemplateContainer<T>::begin, &iter::TemplateContainer<T>::end, "each").
    template define_iterator<typename iter::TemplateContainer<T>::const_iterator(iter::TemplateContainer<T>::*)() const>(&iter::TemplateContainer<T>::begin, &iter::TemplateContainer<T>::end, "each_const").
    template define_iterator<std::reverse_iterator<iter::TemplateContainer<T>::iterator>(iter::TemplateContainer<T>::*)()>(&iter::TemplateContainer<T>::rbegin, &iter::TemplateContainer<T>::rend, "each_reverse").
    template define_iterator<std::reverse_iterator<iter::TemplateContainer<T>::const_iterator>(iter::TemplateContainer<T>::*)() const>(&iter::TemplateContainer<T>::rbegin, &iter::TemplateContainer<T>::rend, "each_reverse_const");
};

