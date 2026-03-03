template<typename T>
inline Rice::Data_Type<Guards::DataType<T>> DataType_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Guards::DataType<T>>(parent, name)
    .template define_singleton_function<int(*)()>("depth", &Guards::DataType<T>::depth);
}
