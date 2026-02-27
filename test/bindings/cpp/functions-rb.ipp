template<typename T, int N>
inline Rice::Data_Type<nontype_args::Container<T, N>> Container_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<nontype_args::Container<T, N>>(parent, name);
}

