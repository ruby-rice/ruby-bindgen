template<typename T, int Rows, int Cols>
inline Rice::Data_Type<cv::Matx<T, Rows, Cols>> Matx_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<cv::Matx<T, Rows, Cols>>(parent, name).
    define_constructor(Constructor<cv::Matx<T, Rows, Cols>>()).
    template define_method<T(cv::Matx<T, Rows, Cols>::*)(int, int) const>("[]", &cv::Matx<T, Rows, Cols>::operator(),
      Arg("i"), Arg("j"));
}

