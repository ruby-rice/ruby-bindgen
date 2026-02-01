template<typename T>
inline Rice::Data_Type<Outer::UsesSkippedType<T>> UsesSkippedType_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Outer::UsesSkippedType<T>>(parent, name).
    define_constructor(Constructor<Outer::UsesSkippedType<T>>()).
    template define_method<void(Outer::UsesSkippedType<T>::*)()>("normal_method", &Outer::UsesSkippedType<T>::normalMethod);
}

template<typename T>
inline Rice::Data_Type<Outer::Wrapper<T>> Wrapper_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Outer::Wrapper<T>>(parent, name).
    define_constructor(Constructor<Outer::Wrapper<T>>()).
    template define_method<void(Outer::Wrapper<T>::*)(T*)>("wrap", &Outer::Wrapper<T>::wrap,
      std::conditional_t<std::is_fundamental_v<T>, ArgBuffer, Arg>("obj"));
}

