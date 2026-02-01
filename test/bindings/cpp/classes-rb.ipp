template<typename T>
inline Rice::Data_Type<Outer::foobar::wrapper<T>> wrapper_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Outer::foobar::wrapper<T>>(parent, name).
    define_attr("item", &Outer::foobar::wrapper<T>::item);
}

