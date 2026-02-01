template<typename Data_Type_T, typename T>
inline void wrapper_builder(Data_Type_T& klass)
{
  klass.define_attr("item", &Outer::foobar::wrapper<T>::item);
};

