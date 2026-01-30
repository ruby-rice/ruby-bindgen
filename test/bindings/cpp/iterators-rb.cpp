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

void Init_Iterators()
{
  Module rb_mIter = define_module("Iter");

  Rice::Data_Type<iter::Pixel> rb_cIterPixel = define_class_under<iter::Pixel>(rb_mIter, "Pixel").
    define_constructor(Constructor<iter::Pixel>()).
    define_constructor(Constructor<iter::Pixel, int, int, int>(),
      Arg("r"), Arg("g"), Arg("b")).
    define_attr("r", &iter::Pixel::r).
    define_attr("g", &iter::Pixel::g).
    define_attr("b", &iter::Pixel::b);

  Rice::Data_Type<iter::PixelIterator> rb_cIterPixelIterator = define_class_under<iter::PixelIterator>(rb_mIter, "PixelIterator").
    define_constructor(Constructor<iter::PixelIterator>()).
    define_constructor(Constructor<iter::PixelIterator, iter::PixelIterator::pointer>(),
      Arg("p")).
    define_method<iter::PixelIterator::reference(iter::PixelIterator::*)() const>("dereference", &iter::PixelIterator::operator*).
    define_method<iter::PixelIterator&(iter::PixelIterator::*)()>("increment", &iter::PixelIterator::operator++).
    define_method<bool(iter::PixelIterator::*)(const iter::PixelIterator&) const>("!=", &iter::PixelIterator::operator!=,
      Arg("other"));

  Rice::Data_Type<iter::ConstPixelIterator> rb_cIterConstPixelIterator = define_class_under<iter::ConstPixelIterator>(rb_mIter, "ConstPixelIterator").
    define_constructor(Constructor<iter::ConstPixelIterator>()).
    define_constructor(Constructor<iter::ConstPixelIterator, iter::ConstPixelIterator::pointer>(),
      Arg("p")).
    define_method<iter::ConstPixelIterator::reference(iter::ConstPixelIterator::*)() const>("dereference", &iter::ConstPixelIterator::operator*).
    define_method<iter::ConstPixelIterator&(iter::ConstPixelIterator::*)()>("increment", &iter::ConstPixelIterator::operator++).
    define_method<bool(iter::ConstPixelIterator::*)(const iter::ConstPixelIterator&) const>("!=", &iter::ConstPixelIterator::operator!=,
      Arg("other"));

  Rice::Data_Type<iter::ReversePixelIterator> rb_cIterReversePixelIterator = define_class_under<iter::ReversePixelIterator>(rb_mIter, "ReversePixelIterator").
    define_constructor(Constructor<iter::ReversePixelIterator>()).
    define_constructor(Constructor<iter::ReversePixelIterator, iter::ReversePixelIterator::pointer>(),
      Arg("p")).
    define_method<iter::ReversePixelIterator::reference(iter::ReversePixelIterator::*)() const>("dereference", &iter::ReversePixelIterator::operator*).
    define_method<iter::ReversePixelIterator&(iter::ReversePixelIterator::*)()>("increment", &iter::ReversePixelIterator::operator++).
    define_method<bool(iter::ReversePixelIterator::*)(const iter::ReversePixelIterator&) const>("!=", &iter::ReversePixelIterator::operator!=,
      Arg("other"));

  Rice::Data_Type<iter::ConstReversePixelIterator> rb_cIterConstReversePixelIterator = define_class_under<iter::ConstReversePixelIterator>(rb_mIter, "ConstReversePixelIterator").
    define_constructor(Constructor<iter::ConstReversePixelIterator>()).
    define_constructor(Constructor<iter::ConstReversePixelIterator, iter::ConstReversePixelIterator::pointer>(),
      Arg("p")).
    define_method<iter::ConstReversePixelIterator::reference(iter::ConstReversePixelIterator::*)() const>("dereference", &iter::ConstReversePixelIterator::operator*).
    define_method<iter::ConstReversePixelIterator&(iter::ConstReversePixelIterator::*)()>("increment", &iter::ConstReversePixelIterator::operator++).
    define_method<bool(iter::ConstReversePixelIterator::*)(const iter::ConstReversePixelIterator&) const>("!=", &iter::ConstReversePixelIterator::operator!=,
      Arg("other"));

  Rice::Data_Type<iter::Bitmap> rb_cIterBitmap = define_class_under<iter::Bitmap>(rb_mIter, "Bitmap").
    define_constructor(Constructor<iter::Bitmap>()).
    define_iterator<iter::PixelIterator(iter::Bitmap::*)() noexcept>(&iter::Bitmap::begin, &iter::Bitmap::end, "each").
    define_iterator<iter::ConstPixelIterator(iter::Bitmap::*)() const noexcept>(&iter::Bitmap::begin, &iter::Bitmap::end, "each_const").
    define_iterator<iter::ReversePixelIterator(iter::Bitmap::*)() noexcept>(&iter::Bitmap::rbegin, &iter::Bitmap::rend, "each_reverse").
    define_iterator<iter::ConstReversePixelIterator(iter::Bitmap::*)() const noexcept>(&iter::Bitmap::rbegin, &iter::Bitmap::rend, "each_reverse_const");

  Rice::Data_Type<iter::IncompleteIterator> rb_cIterIncompleteIterator = define_class_under<iter::IncompleteIterator>(rb_mIter, "IncompleteIterator").
    define_constructor(Constructor<iter::IncompleteIterator>()).
    define_constructor(Constructor<iter::IncompleteIterator, iter::Pixel*>(),
      Arg("p")).
    define_method<iter::Pixel&(iter::IncompleteIterator::*)() const>("dereference", &iter::IncompleteIterator::operator*).
    define_method<iter::Pixel*(iter::IncompleteIterator::*)() const>("arrow", &iter::IncompleteIterator::operator->).
    define_method<iter::IncompleteIterator&(iter::IncompleteIterator::*)()>("increment", &iter::IncompleteIterator::operator++).
    define_method<iter::IncompleteIterator(iter::IncompleteIterator::*)(int)>("increment_post", &iter::IncompleteIterator::operator++,
      Arg("arg_0"));

  Rice::Data_Type<iter::IncompleteBitmap> rb_cIterIncompleteBitmap = define_class_under<iter::IncompleteBitmap>(rb_mIter, "IncompleteBitmap").
    define_constructor(Constructor<iter::IncompleteBitmap>()).
    define_iterator<iter::IncompleteIterator(iter::IncompleteBitmap::*)()>(&iter::IncompleteBitmap::begin, &iter::IncompleteBitmap::end, "each");

  Rice::Data_Type<iter::TemplateContainer<iter::Pixel>> rb_cPixelContainer = define_class_under<iter::TemplateContainer<iter::Pixel>>(rb_mIter, "PixelContainer").
    define(&TemplateContainer_builder<Data_Type<iter::TemplateContainer<iter::Pixel>>, iter::Pixel>);

  Rice::Data_Type<iter::VectorBitmap> rb_cIterVectorBitmap = define_class_under<iter::VectorBitmap>(rb_mIter, "VectorBitmap").
    define_constructor(Constructor<iter::VectorBitmap>()).
    define_iterator<std::vector<iter::Pixel>::iterator(iter::VectorBitmap::*)() noexcept>(&iter::VectorBitmap::begin, &iter::VectorBitmap::end, "each").
    define_iterator<std::vector<iter::Pixel>::const_iterator(iter::VectorBitmap::*)() const noexcept>(&iter::VectorBitmap::begin, &iter::VectorBitmap::end, "each_const").
    define_iterator<std::vector<iter::Pixel>::reverse_iterator(iter::VectorBitmap::*)() noexcept>(&iter::VectorBitmap::rbegin, &iter::VectorBitmap::rend, "each_reverse").
    define_iterator<std::vector<iter::Pixel>::const_reverse_iterator(iter::VectorBitmap::*)() const noexcept>(&iter::VectorBitmap::rbegin, &iter::VectorBitmap::rend, "each_reverse_const");
}