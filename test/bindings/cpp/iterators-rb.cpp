#include <iterators.hpp>
#include "iterators-rb.hpp"

using namespace Rice;

Rice::Class rb_cIterBitmap;
Rice::Class rb_cIterConstPixelIterator;
Rice::Class rb_cIterConstReversePixelIterator;
Rice::Class rb_cIterPixel;
Rice::Class rb_cIterPixelIterator;
Rice::Class rb_cIterReversePixelIterator;
Rice::Class rb_cIterVectorBitmap;

void Init_Iterators()
{
  Module rb_mIter = define_module("Iter");

  rb_cIterPixel = define_class_under<iter::Pixel>(rb_mIter, "Pixel").
    define_constructor(Constructor<iter::Pixel>()).
    define_constructor(Constructor<iter::Pixel, int, int, int>(),
      Arg("r"), Arg("g"), Arg("b")).
    define_attr("r", &iter::Pixel::r).
    define_attr("g", &iter::Pixel::g).
    define_attr("b", &iter::Pixel::b);

  rb_cIterPixelIterator = define_class_under<iter::PixelIterator>(rb_mIter, "PixelIterator").
    define_constructor(Constructor<iter::PixelIterator>()).
    define_constructor(Constructor<iter::PixelIterator, iter::PixelIterator::pointer>(),
      Arg("p")).
    define_method("dereference", &iter::PixelIterator::operator*).
    define_method("increment_pre", &iter::PixelIterator::operator++).
    define_method("!=", &iter::PixelIterator::operator!=,
      Arg("other"));

  rb_cIterConstPixelIterator = define_class_under<iter::ConstPixelIterator>(rb_mIter, "ConstPixelIterator").
    define_constructor(Constructor<iter::ConstPixelIterator>()).
    define_constructor(Constructor<iter::ConstPixelIterator, iter::ConstPixelIterator::pointer>(),
      Arg("p")).
    define_method("dereference", &iter::ConstPixelIterator::operator*).
    define_method("increment_pre", &iter::ConstPixelIterator::operator++).
    define_method("!=", &iter::ConstPixelIterator::operator!=,
      Arg("other"));

  rb_cIterReversePixelIterator = define_class_under<iter::ReversePixelIterator>(rb_mIter, "ReversePixelIterator").
    define_constructor(Constructor<iter::ReversePixelIterator>()).
    define_constructor(Constructor<iter::ReversePixelIterator, iter::ReversePixelIterator::pointer>(),
      Arg("p")).
    define_method("dereference", &iter::ReversePixelIterator::operator*).
    define_method("increment_pre", &iter::ReversePixelIterator::operator++).
    define_method("!=", &iter::ReversePixelIterator::operator!=,
      Arg("other"));

  rb_cIterConstReversePixelIterator = define_class_under<iter::ConstReversePixelIterator>(rb_mIter, "ConstReversePixelIterator").
    define_constructor(Constructor<iter::ConstReversePixelIterator>()).
    define_constructor(Constructor<iter::ConstReversePixelIterator, iter::ConstReversePixelIterator::pointer>(),
      Arg("p")).
    define_method("dereference", &iter::ConstReversePixelIterator::operator*).
    define_method("increment_pre", &iter::ConstReversePixelIterator::operator++).
    define_method("!=", &iter::ConstReversePixelIterator::operator!=,
      Arg("other"));

  rb_cIterBitmap = define_class_under<iter::Bitmap>(rb_mIter, "Bitmap").
    define_constructor(Constructor<iter::Bitmap>()).
    define_iterator<iter::PixelIterator(iter::Bitmap::*)() noexcept>(&iter::Bitmap::begin, &iter::Bitmap::end, "each").
    define_iterator<iter::ConstPixelIterator(iter::Bitmap::*)() const noexcept>(&iter::Bitmap::begin, &iter::Bitmap::end, "each_const").
    define_iterator<iter::ReversePixelIterator(iter::Bitmap::*)() noexcept>(&iter::Bitmap::rbegin, &iter::Bitmap::rend, "each_reverse").
    define_iterator<iter::ConstReversePixelIterator(iter::Bitmap::*)() const noexcept>(&iter::Bitmap::rbegin, &iter::Bitmap::rend, "each_reverse_const");

  rb_cIterVectorBitmap = define_class_under<iter::VectorBitmap>(rb_mIter, "VectorBitmap").
    define_constructor(Constructor<iter::VectorBitmap>()).
    define_iterator<std::vector<iter::Pixel>::iterator(iter::VectorBitmap::*)() noexcept>(&iter::VectorBitmap::begin, &iter::VectorBitmap::end, "each").
    define_iterator<std::vector<iter::Pixel>::const_iterator(iter::VectorBitmap::*)() const noexcept>(&iter::VectorBitmap::begin, &iter::VectorBitmap::end, "each_const").
    define_iterator<std::vector<iter::Pixel>::reverse_iterator(iter::VectorBitmap::*)() noexcept>(&iter::VectorBitmap::rbegin, &iter::VectorBitmap::rend, "each_reverse").
    define_iterator<std::vector<iter::Pixel>::const_reverse_iterator(iter::VectorBitmap::*)() const noexcept>(&iter::VectorBitmap::rbegin, &iter::VectorBitmap::rend, "each_reverse_const");
}