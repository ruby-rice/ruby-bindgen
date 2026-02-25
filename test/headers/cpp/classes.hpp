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
    int array_field[3];                       // array field (currently skipped)
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

  // Test inherited overloaded methods.
  // When a derived class inherits overloaded methods from a base class,
  // the bindings need explicit function pointer signatures to disambiguate.
  // This tests the fix for cv::xfeatures2d::AffineFeature2D::detect issue.
  class FeatureDetector
  {
  public:
    virtual ~FeatureDetector() = default;

    // Overloaded detect methods
    virtual void detect(int image, int& keypoints) const;
    virtual void detect(int image, int& keypoints, int mask) const;

    // Overloaded compute methods
    virtual void compute(int image, int& keypoints, int& descriptors) const;
    virtual void compute(int images, int& keypoints, int& descriptors, bool useProvidedKeypoints) const;
  };

  class DescriptorExtractor : public FeatureDetector
  {
  public:
    // This class inherits detect and compute overloads from FeatureDetector,
    // but may add its own methods.
    void extract(int image, int& descriptors) const;
  };

  class Feature2D : public DescriptorExtractor
  {
  public:
    // Bring base class methods into scope with using declarations.
    // This simulates cv::Feature2D pattern where inherited overloaded methods
    // are explicitly brought into derived class scope.
    using FeatureDetector::detect;
    using FeatureDetector::compute;

    // Additional method specific to this class
    void detectAndCompute(int image, int mask, int& keypoints, int& descriptors) const;
  };

  class AffineFeature2D : public Feature2D
  {
  public:
    // This class should also need explicit signatures for inherited detect/compute
    // because they are overloaded in the base class hierarchy.
    using Feature2D::detect;
    using Feature2D::compute;

    // Override one variant
    virtual void detect(int image, int& keypoints, int mask) const override;
  };

  // Test cross-namespace type qualification in method parameters.
  // When a method takes a type from a sibling namespace with partial qualification
  // (e.g., "Sibling::Target" instead of "Outer::Sibling::Target"), the generated
  // code must use the fully qualified name.
  // This reproduces the cv::mcc::CCheckerDetector::setNet(dnn::Net) bug where
  // the parameter type was generated as "dnn::Net" instead of "cv::dnn::Net".
  namespace Sibling
  {
    class Target
    {
    public:
      int value;
    };
  }

  namespace Other
  {
    class User
    {
    public:
      void take_target(Sibling::Target t);
      Sibling::Target return_target();
    };
  }
}
