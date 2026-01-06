const int GLOBAL_CONSTANT = 1;
int globalVariable = 2;

namespace Outer
{
  // Simple class to use in template argument qualification test
  class Range
  {
  public:
    int start;
    int end;
  };

  // Simple template to test template argument qualification (avoids std::vector)
  template<typename T>
  class SimpleVector
  {
  public:
    T* data;
    int size;
  };

  const int NAMESPACE_CONSTANT = 3;
  int namespaceVariable = 4;

  class BaseClass
  {
  };

  class MyClass : public BaseClass
  {
    public:
        static const int SOME_CONSTANT = 42;
        static int static_field_one;
        static bool staticMethodOne();

        MyClass();
        MyClass(int a);
        ~MyClass();

        void methodOne(int a);
        void methodTwo(int a, bool b);

        void overloaded(int a);
        void overloaded(bool a);

        int field_one = 3;

    private:
        int field_two = 4;
        void methodThree();
  };

  namespace Inner
  {
    class ContainerClass
    {
    public:
        class Callback
        {
        public:
          virtual ~Callback();
          virtual bool compute() const;
        };
        Callback callback;

        struct Config
        {
        public:
            bool enable;
        };
        Config config;

        enum GridType
        {
          SYMMETRIC_GRID, ASYMMETRIC_GRID
        };
        GridType gridType;
    };

    // Test nested class type qualification in default parameters
    // Similar to cv::cuda::GpuMat::Allocator pattern
    class GpuMat
    {
    public:
        class Allocator
        {
        public:
            virtual ~Allocator();
        };

        static Allocator* defaultAllocator();

        GpuMat();
        // Test that GpuMat::Allocator* is fully qualified as Outer::Inner::GpuMat::Allocator*
        GpuMat(int rows, int cols, GpuMat::Allocator* allocator = GpuMat::defaultAllocator());
    };

    // Test C++11 using type alias qualification in parameters
    // Similar to cv::cuda::GpuMatND::SizeArray pattern
    class GpuMatND
    {
    public:
        using SizeArray = int[3];
        using StepArray = int[3];

        static StepArray& defaultStepArray();

        GpuMatND();
        // Test that SizeArray is fully qualified as Outer::Inner::GpuMatND::SizeArray
        GpuMatND(SizeArray size, int type);
        GpuMatND(SizeArray size, int type, void* data, StepArray step = GpuMatND::defaultStepArray());

        // Test template argument qualification
        // SimpleVector<Range> should become Outer::SimpleVector<Outer::Range>
        GpuMatND(const SimpleVector<Range>& ranges);
    };
  }
}
