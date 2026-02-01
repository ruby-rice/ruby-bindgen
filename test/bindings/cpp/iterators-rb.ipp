template<typename T>
inline Rice::Data_Type<iter::TemplateContainer<T>> TemplateContainer_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<iter::TemplateContainer<T>>(parent, name).
    define_constructor(Constructor<iter::TemplateContainer<T>>()).
    template define_iterator<typename iter::TemplateContainer<T>::iterator(iter::TemplateContainer<T>::*)()>(&iter::TemplateContainer<T>::begin, &iter::TemplateContainer<T>::end, "each").
    template define_iterator<typename iter::TemplateContainer<T>::const_iterator(iter::TemplateContainer<T>::*)() const>(&iter::TemplateContainer<T>::begin, &iter::TemplateContainer<T>::end, "each_const").
    template define_iterator<std::reverse_iterator<iter::TemplateContainer<T>::iterator>(iter::TemplateContainer<T>::*)()>(&iter::TemplateContainer<T>::rbegin, &iter::TemplateContainer<T>::rend, "each_reverse").
    template define_iterator<std::reverse_iterator<iter::TemplateContainer<T>::const_iterator>(iter::TemplateContainer<T>::*)() const>(&iter::TemplateContainer<T>::rbegin, &iter::TemplateContainer<T>::rend, "each_reverse_const");
}

