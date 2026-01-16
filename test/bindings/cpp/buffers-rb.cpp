#include <buffers.hpp>
#include "buffers-rb.hpp"

using namespace Rice;

void Init_Buffers()
{
  Rice::Data_Type<BufferClass> rb_cBufferClass = define_class<BufferClass>("BufferClass").
    define_constructor(Constructor<BufferClass>()).
    define_attr("value", &BufferClass::value);

  define_global_function("process_int_buffer", &processIntBuffer,
    ArgBuffer("data"), Arg("size"));

  define_global_function("process_double_buffer", &processDoubleBuffer,
    ArgBuffer("values"), Arg("count"));

  define_global_function("process_char_buffer", &processCharBuffer,
    Arg("buffer"), Arg("length"));

  define_global_function("process_unsigned_buffer", &processUnsignedBuffer,
    ArgBuffer("data"), Arg("size"));

  define_global_function("read_int_buffer", &readIntBuffer,
    ArgBuffer("data"), Arg("size"));

  define_global_function("read_double_buffer", &readDoubleBuffer,
    ArgBuffer("values"), Arg("count"));

  define_global_function("get_min_max", &getMinMax,
    ArgBuffer("input"), Arg("size"), ArgBuffer("min_val"), ArgBuffer("max_val"));

  define_global_function("process_int_arrays", &processIntArrays,
    ArgBuffer("arrays"), Arg("count"));

  define_global_function("process_string_array", &processStringArray,
    ArgBuffer("strings"), Arg("count"));

  define_global_function("process_object_array", &processObjectArray,
    ArgBuffer("objects"), Arg("count"));

  define_global_function("process_const_object_array", &processConstObjectArray,
    ArgBuffer("objects"), Arg("count"));

  define_global_function("create_int_buffer", &createIntBuffer,
    Arg("size"), ReturnBuffer());

  define_global_function("create_double_buffer", &createDoubleBuffer,
    Arg("size"), ReturnBuffer());

  define_global_function("get_read_only_float_buffer", &getReadOnlyFloatBuffer,
    ReturnBuffer());

  define_global_function("create_int_arrays", &createIntArrays,
    Arg("rows"), Arg("cols"), ReturnBuffer());

  define_global_function("create_object_array", &createObjectArray,
    Arg("count"), ReturnBuffer());

  Rice::Data_Type<DataProcessor> rb_cDataProcessor = define_class<DataProcessor>("DataProcessor").
    define_constructor(Constructor<DataProcessor>()).
    define_method("set_data", &DataProcessor::setData,
      ArgBuffer("data"), Arg("size")).
    define_method("set_weights", &DataProcessor::setWeights,
      ArgBuffer("weights"), Arg("count")).
    define_method("set_matrices", &DataProcessor::setMatrices,
      ArgBuffer("matrices"), Arg("count")).
    define_method("set_objects", &DataProcessor::setObjects,
      ArgBuffer("objects"), Arg("count")).
    define_method("get_data", &DataProcessor::getData,
      ReturnBuffer()).
    define_method("get_weights", &DataProcessor::getWeights,
      ReturnBuffer()).
    define_method("get_matrices", &DataProcessor::getMatrices,
      ReturnBuffer()).
    define_method("get_objects", &DataProcessor::getObjects,
      ReturnBuffer()).
    define_method("compute_stats", &DataProcessor::computeStats,
      ArgBuffer("mean"), ArgBuffer("stddev"));
}