#include <buffers.hpp>
#include "buffers-rb.hpp"

using namespace Rice;



void Init_Buffers()
{
  Module rb_mBufferNS = define_module("BufferNS");

  Rice::Data_Type<BufferNS::Point2f> rb_cBufferNSPoint2f = define_class_under<BufferNS::Point2f>(rb_mBufferNS, "Point2f").
    define_constructor(Constructor<BufferNS::Point2f>()).
    define_attr("x", &BufferNS::Point2f::x).
    define_attr("y", &BufferNS::Point2f::y);

  Rice::Data_Type<BufferNS::Shape> rb_cBufferNSShape = define_class_under<BufferNS::Shape>(rb_mBufferNS, "Shape").
    define_constructor(Constructor<BufferNS::Shape>()).
    define_method<void(BufferNS::Shape::*)(BufferNS::Point2f[]) const>("set_points", &BufferNS::Shape::setPoints,
      Arg("pts"));

  Rice::Data_Type<BufferClass> rb_cBufferClass = define_class<BufferClass>("BufferClass").
    define_constructor(Constructor<BufferClass>()).
    define_attr("value", &BufferClass::value);

  define_global_function<void(*)(int, size_t[], size_t[])>("process_kernel_dims", &processKernelDims,
    Arg("dims"), Arg("globalsize"), Arg("localsize"));

  define_global_function<void(*)(int*, int)>("process_int_buffer", &processIntBuffer,
    ArgBuffer("data"), Arg("size"));

  define_global_function<void(*)(double*, int)>("process_double_buffer", &processDoubleBuffer,
    ArgBuffer("values"), Arg("count"));

  define_global_function<void(*)(char*, int)>("process_char_buffer", &processCharBuffer,
    Arg("buffer"), Arg("length"));

  define_global_function<void(*)(unsigned char*, size_t)>("process_unsigned_buffer", &processUnsignedBuffer,
    ArgBuffer("data"), Arg("size"));

  define_global_function<void(*)(const int*, int)>("read_int_buffer", &readIntBuffer,
    ArgBuffer("data"), Arg("size"));

  define_global_function<void(*)(const double*, int)>("read_double_buffer", &readDoubleBuffer,
    ArgBuffer("values"), Arg("count"));

  define_global_function<void(*)(const double*, int, double*, double*)>("get_min_max", &getMinMax,
    ArgBuffer("input"), Arg("size"), ArgBuffer("min_val"), ArgBuffer("max_val"));

  define_global_function<void(*)(int**, int)>("process_int_arrays", &processIntArrays,
    ArgBuffer("arrays"), Arg("count"));

  define_global_function<void(*)(char**, int)>("process_string_array", &processStringArray,
    ArgBuffer("strings"), Arg("count"));

  define_global_function<void(*)(BufferClass**, int)>("process_object_array", &processObjectArray,
    ArgBuffer("objects"), Arg("count"));

  define_global_function<void(*)(const BufferClass**, int)>("process_const_object_array", &processConstObjectArray,
    ArgBuffer("objects"), Arg("count"));

  define_global_function<int*(*)(int)>("create_int_buffer", &createIntBuffer,
    Arg("size"), ReturnBuffer());

  define_global_function<double*(*)(int)>("create_double_buffer", &createDoubleBuffer,
    Arg("size"), ReturnBuffer());

  define_global_function<const float*(*)()>("get_read_only_float_buffer", &getReadOnlyFloatBuffer,
    ReturnBuffer());

  define_global_function<int**(*)(int, int)>("create_int_arrays", &createIntArrays,
    Arg("rows"), Arg("cols"), ReturnBuffer());

  define_global_function<BufferClass**(*)(int)>("create_object_array", &createObjectArray,
    Arg("count"), ReturnBuffer());

  Rice::Data_Type<DataProcessor> rb_cDataProcessor = define_class<DataProcessor>("DataProcessor").
    define_constructor(Constructor<DataProcessor>()).
    define_method<void(DataProcessor::*)(int*, int)>("set_data", &DataProcessor::setData,
      ArgBuffer("data"), Arg("size")).
    define_method<void(DataProcessor::*)(const double*, int)>("set_weights", &DataProcessor::setWeights,
      ArgBuffer("weights"), Arg("count")).
    define_method<void(DataProcessor::*)(float**, int)>("set_matrices", &DataProcessor::setMatrices,
      ArgBuffer("matrices"), Arg("count")).
    define_method<void(DataProcessor::*)(BufferClass**, int)>("set_objects", &DataProcessor::setObjects,
      ArgBuffer("objects"), Arg("count")).
    define_method<int*(DataProcessor::*)()>("get_data", &DataProcessor::getData,
      ReturnBuffer()).
    define_method<const double*(DataProcessor::*)()>("get_weights", &DataProcessor::getWeights,
      ReturnBuffer()).
    define_method<float**(DataProcessor::*)()>("get_matrices", &DataProcessor::getMatrices,
      ReturnBuffer()).
    define_method<BufferClass**(DataProcessor::*)()>("get_objects", &DataProcessor::getObjects,
      ReturnBuffer()).
    define_method<void(DataProcessor::*)(double*, double*)>("compute_stats", &DataProcessor::computeStats,
      ArgBuffer("mean"), ArgBuffer("stddev"));

  define_global_function<void(*)(int*, int, ProcessCallback, void*)>("process_with_callback", &processWithCallback,
    ArgBuffer("data"), Arg("size"), Arg("callback"), ArgBuffer("user_data"));

  define_global_function<void(*)(bool (*)(int*, int*, void*), void*)>("set_face_detector", &setFaceDetector,
    Arg("detector"), ArgBuffer("user_data"));

  Rice::Data_Type<EventHandler> rb_cEventHandler = define_class<EventHandler>("EventHandler").
    define_constructor(Constructor<EventHandler>()).
    define_method<void(EventHandler::*)(void (*)(int, void*), void*)>("set_callback", &EventHandler::setCallback,
      Arg("callback"), ArgBuffer("user_data")).
    define_method<void(EventHandler::*)(bool (*)(const char*))>("set_validator", &EventHandler::setValidator,
      Arg("validate"));

}
