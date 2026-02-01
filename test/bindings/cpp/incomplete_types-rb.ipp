template<typename T>
inline Rice::Data_Type<Outer::Inner::Ptr<T>> Ptr_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Outer::Inner::Ptr<T>>(parent, name).
    define_attr("ptr", &Outer::Inner::Ptr<T>::ptr);
}

template<typename T>
inline Rice::Data_Type<Outer::Inner::Deleter<T>> Deleter_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Outer::Inner::Deleter<T>>(parent, name).
    template define_method<void(Outer::Inner::Deleter<T>::*)(T*) const>("call", &Outer::Inner::Deleter<T>::operator(),
      std::conditional_t<std::is_fundamental_v<T>, ArgBuffer, Arg>("obj"));
}

