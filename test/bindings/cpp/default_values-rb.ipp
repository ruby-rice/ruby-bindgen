template<typename T>
inline Rice::Data_Type<cv::Vec3<T>> Vec3_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<cv::Vec3<T>>(parent, name).
    define_constructor(Constructor<cv::Vec3<T>>()).
    define_constructor(Constructor<cv::Vec3<T>, T, T, T>(),
      Arg("x"), Arg("y"), Arg("z")).
    define_attr("data", &cv::Vec3<T>::data, Rice::AttrAccess::Read).
    template define_singleton_function<cv::Vec3<T>(*)(T)>("all", &cv::Vec3<T>::all,
      Arg("value"));
}

template<typename T>
inline Rice::Data_Type<cv::Affine3<T>> Affine3_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<cv::Affine3<T>>(parent, name).
    define_constructor(Constructor<cv::Affine3<T>>()).
    define_constructor(Constructor<cv::Affine3<T>, const typename cv::Affine3<T>::Vec3Type&, const typename cv::Affine3<T>::Vec3Type&>(),
      Arg("translation"), Arg("scale") = static_cast<const typename cv::Affine3<T>::Vec3Type&>(cv::Affine3<T>::Vec3Type::all(1)));
}

template<typename T>
inline Rice::Data_Type<cv::Rect_<T>> Rect__instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<cv::Rect_<T>>(parent, name).
    define_constructor(Constructor<cv::Rect_<T>>()).
    define_constructor(Constructor<cv::Rect_<T>, T, T, T, T>(),
      Arg("x"), Arg("y"), Arg("width"), Arg("height")).
    define_attr("x", &cv::Rect_<T>::x).
    define_attr("y", &cv::Rect_<T>::y).
    define_attr("width", &cv::Rect_<T>::width).
    define_attr("height", &cv::Rect_<T>::height);
}

