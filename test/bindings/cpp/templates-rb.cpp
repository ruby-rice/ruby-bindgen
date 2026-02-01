#include <templates.hpp>
#include "templates-rb.hpp"

using namespace Rice;

#include "templates-rb.ipp"

void Init_Templates()
{
  Module rb_mInternal = define_module("Internal");

  Rice::Data_Type<Internal::Data<2, 2>> rb_cData22 = Data_instantiate<2, 2>(rb_mInternal, "Data22");

  Module rb_mTests = define_module("Tests");

  Rice::Data_Type<Tests::Matrix<int, 2, 2>> rb_cMatrixInt22 = Matrix_instantiate<int, 2, 2>(rb_mTests, "MatrixInt22");

  Rice::Data_Type<Tests::Matrix<float, 3, 3>> matrix_float33 = Matrix_instantiate<float, 3, 3>(rb_mTests, "MatrixFloat33");

  Rice::Data_Type<Tests::TypeTraits<int>> rb_cTestsTypeTraitsInt = define_class_under<Tests::TypeTraits<int>>(rb_mTests, "TypeTraitsInt").
    define_constructor(Constructor<Tests::TypeTraits<int>>()).
    define_constant("Type", Tests::TypeTraits<int>::type);

  Rice::Data_Type<Tests::TypeTraits<float>> rb_cTestsTypeTraitsFloat = define_class_under<Tests::TypeTraits<float>>(rb_mTests, "TypeTraitsFloat").
    define_constructor(Constructor<Tests::TypeTraits<float>>()).
    define_constant("Type", Tests::TypeTraits<float>::type);

  Rice::Data_Type<Tests::TypeTraits<double>> rb_cTestsTypeTraitsDouble = define_class_under<Tests::TypeTraits<double>>(rb_mTests, "TypeTraitsDouble").
    define_constructor(Constructor<Tests::TypeTraits<double>>()).
    define_constant("Type", Tests::TypeTraits<double>::type);

  Rice::Data_Type<Tests::Transform<float>> rb_cTransformf = Transform_instantiate<float>(rb_mTests, "Transformf");

  Rice::Data_Type<Tests::Transform<double>> rb_cTransformd = Transform_instantiate<double>(rb_mTests, "Transformd");

  Rice::Data_Type<Tests::Item> rb_cTestsItem = define_class_under<Tests::Item>(rb_mTests, "Item").
    define_constructor(Constructor<Tests::Item>()).
    define_attr("value", &Tests::Item::value);

  Rice::Data_Type<Tests::Container<Tests::Item>> rb_cTestsContainerTestsItem = Container_instantiate<Tests::Item>(rb_mTests, "ContainerTestsItem");

  Rice::Data_Type<Tests::Consumer> rb_cTestsConsumer = define_class_under<Tests::Consumer>(rb_mTests, "Consumer").
    define_constructor(Constructor<Tests::Consumer, const Tests::Container<Tests::Item>&>(),
      Arg("items"));

  Rice::Data_Type<Tests::lowercase_type> rb_cTestsLowercaseType = define_class_under<Tests::lowercase_type>(rb_mTests, "LowercaseType").
    define_constructor(Constructor<Tests::lowercase_type>()).
    define_attr("value", &Tests::lowercase_type::value);

  Rice::Data_Type<Tests::TypeTraits<Tests::lowercase_type>> rb_cTestsTypeTraitsLowercaseType = define_class_under<Tests::TypeTraits<Tests::lowercase_type>>(rb_mTests, "TypeTraitsLowercaseType").
    define_constructor(Constructor<Tests::TypeTraits<Tests::lowercase_type>>()).
    define_constant("Type", Tests::TypeTraits<Tests::lowercase_type>::type);

  Rice::Data_Type<Tests::Wrapper<Tests::lowercase_type>> rb_cWrappedLowercase = Wrapper_instantiate<Tests::lowercase_type>(rb_mTests, "WrappedLowercase");

  Rice::Data_Type<Tests::Mat_<float>> rb_cMat1f = Mat__instantiate<float>(rb_mTests, "Mat1f");
}