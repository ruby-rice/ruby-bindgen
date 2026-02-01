template<typename T>
inline Rice::Data_Type<TemplateConstructor<T>> TemplateConstructor_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<TemplateConstructor<T>>(parent, name).
    define_constructor(Constructor<TemplateConstructor<T>>()).
    define_constructor(Constructor<TemplateConstructor<T>, T>(),
      Arg("value"));
}

