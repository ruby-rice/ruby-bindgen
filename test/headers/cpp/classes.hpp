const int GLOBAL_CONSTANT = 1;
int globalVariable = 2;

namespace Outer
{
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
    };

    // Test "safe bool idiom" from pre-C++11 - should be skipped
    // This pattern was used before explicit operator bool() was available
    class Stream
    {
    public:
        typedef void (Stream::*bool_type)() const;
        void this_type_does_not_support_comparisons() const {}

        // This conversion operator should be SKIPPED (safe bool idiom)
        operator bool_type() const;

        // Regular conversion operators should still work
        operator int() const;
    };
  }

  // Test attribute access detection (const, non-assignable, etc.)
  class NonAssignable
  {
  public:
    NonAssignable() = default;
    NonAssignable(const NonAssignable&) = default;
    NonAssignable& operator=(const NonAssignable&) = delete;
  };

  class ProtectedAssign
  {
  public:
    ProtectedAssign() = default;
  protected:
    ProtectedAssign& operator=(const ProtectedAssign&) = default;
  };

  class AttributeTest
  {
  public:
    int regular_field = 0;                    // read-write
    const int const_field = 42;               // read-only (const)
    NonAssignable non_assignable_field;       // read-only (deleted operator=)
    ProtectedAssign protected_assign_field;   // read-only (protected operator=)
  };

  // Test word boundary matching in template argument qualification.
  // The class "foo" should not match "foo" inside "foobar" namespace.
  // This tests the fix for the cvflann::anyimpl::choose_policy<any> bug
  // where "any" was being replaced inside "anyimpl", causing duplicate namespaces.
  class foo
  {
  public:
    int value;
  };

  namespace foobar
  {
    template<typename T>
    struct wrapper
    {
      T item;
    };

    // Forward declaration of foo inside foobar namespace
    struct foo;

    // Template specialization using the forward-declared foobar::foo
    // This should generate: Outer::foobar::wrapper<Outer::foobar::foo>
    // NOT: Outer::Outer::foobar::foobar::wrapper<Outer::foo>
    template<>
    struct wrapper<foo>
    {
    };
  }
}
