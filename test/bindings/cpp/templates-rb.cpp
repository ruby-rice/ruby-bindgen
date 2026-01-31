#include "templates-rb.ipp"

void Init_Templates()
{
  Module rb_mInternal = define_module("Internal");

  Rice::Data_Type<Internal::Data<2, 2>> rb_cData22 = define_class_under<Internal::Data<2, 2>>(rb_mInternal, "Data22").
    define(&Data_builder<Data_Type<Internal::Data<2, 2>>, 2, 2>);

  Module rb_mTests = define_module("Tests");

  Rice::Data_Type<Tests::Matrix<int, 2, 2>> rb_cMatrixInt22 = define_class_under<Tests::Matrix<int, 2, 2>>(rb_mTests, "MatrixInt22").
    define(&Matrix_builder<Data_Type<Tests::Matrix<int, 2, 2>>, int, 2, 2>);

  Rice::Data_Type<Tests::Matrix<float, 3, 3>> matrix_float33 = define_class_under<Tests::Matrix<float, 3, 3>>(rb_mTests, "MatrixFloat33").
    define(&Matrix_builder<Data_Type<Tests::Matrix<float, 3, 3>>, float, 3, 3>);

  Rice::Data_Type<Tests::TypeTraits<int>> rb_cTestsTypeTraitsInt = define_class_under<Tests::TypeTraits<int>>(rb_mTests, "TypeTraitsInt").
    define_constructor(Constructor<Tests::TypeTraits<int>>()).
    define_constant("Type", Tests::TypeTraits<int>::type);

  Rice::Data_Type<Tests::TypeTraits<float>> rb_cTestsTypeTraitsFloat = define_class_under<Tests::TypeTraits<float>>(rb_mTests, "TypeTraitsFloat").
    define_constructor(Constructor<Tests::TypeTraits<float>>()).
    define_constant("Type", Tests::TypeTraits<float>::type);

  Rice::Data_Type<Tests::TypeTraits<double>> rb_cTestsTypeTraitsDouble = define_class_under<Tests::TypeTraits<double>>(rb_mTests, "TypeTraitsDouble").
    define_constructor(Constructor<Tests::TypeTraits<double>>()).
    define_constant("Type", Tests::TypeTraits<double>::type);

  Rice::Data_Type<Tests::Transform<float>> rb_cTransformf = define_class_under<Tests::Transform<float>>(rb_mTests, "Transformf").
    define(&Transform_builder<Data_Type<Tests::Transform<float>>, float>);

  Rice::Data_Type<Tests::Transform<double>> rb_cTransformd = define_class_under<Tests::Transform<double>>(rb_mTests, "Transformd").
    define(&Transform_builder<Data_Type<Tests::Transform<double>>, double>);

  Rice::Data_Type<Tests::Item> rb_cTestsItem = define_class_under<Tests::Item>(rb_mTests, "Item").
    define_constructor(Constructor<Tests::Item>()).
    define_attr("value", &Tests::Item::value);

  Rice::Data_Type<Tests::Container<Tests::Item>> rb_cTestsContainerTestsItem = define_class_under<Tests::Container<Tests::Item>>(rb_mTests, "ContainerTestsItem").
    define(&Container_builder<Data_Type<Tests::Container<Tests::Item>>, Tests::Item>);

  Rice::Data_Type<Tests::Consumer> rb_cTestsConsumer = define_class_under<Tests::Consumer>(rb_mTests, "Consumer").
    define_constructor(Constructor<Tests::Consumer, const Tests::Container<Tests::Item>&>(),
      Arg("items"));

  Rice::Data_Type<Tests::lowercase_type> rb_cTestsLowercaseType = define_class_under<Tests::lowercase_type>(rb_mTests, "LowercaseType").
    define_constructor(Constructor<Tests::lowercase_type>()).
    define_attr("value", &Tests::lowercase_type::value);

  Rice::Data_Type<Tests::TypeTraits<Tests::lowercase_type>> rb_cTestsTypeTraitsLowercaseType = define_class_under<Tests::TypeTraits<Tests::lowercase_type>>(rb_mTests, "TypeTraitsLowercaseType").
    define_constructor(Constructor<Tests::TypeTraits<Tests::lowercase_type>>()).
    define_constant("Type", Tests::TypeTraits<Tests::lowercase_type>::type);

  Rice::Data_Type<Tests::Wrapper<Tests::lowercase_type>> rb_cWrappedLowercase = define_class_under<Tests::Wrapper<Tests::lowercase_type>>(rb_mTests, "WrappedLowercase").
    define(&Wrapper_builder<Data_Type<Tests::Wrapper<Tests::lowercase_type>>, Tests::lowercase_type>);

  Rice::Data_Type<Tests::Mat_<float>> rb_cMat1f = define_class_under<Tests::Mat_<float>>(rb_mTests, "Mat1f").
    define(&Mat__builder<Data_Type<Tests::Mat_<float>>, float>);
}