template<typename T>
inline Rice::Data_Type<DataPtr<T>> DataPtr_instantiate(Rice::Module& parent, const char* name)
{
  return Rice::define_class_under<DataPtr<T>>(parent, name).
    define_attr("data", &DataPtr<T>::data).
    define_constructor(Constructor<DataPtr<T>>()).
    define_constructor(Constructor<DataPtr<T>, T*>(),
      std::conditional_t<std::is_fundamental_v<T>, ArgBuffer, Arg>("ptr")).
    define_method("to_ptr", [](DataPtr<T>& self) -> T*
    {
      return self;
    }).
    define_method("to_const_ptr", [](const DataPtr<T>& self) -> const T*
    {
      return self;
    });
}

