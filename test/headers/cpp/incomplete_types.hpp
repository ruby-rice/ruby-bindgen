// Test case for incomplete/opaque types:
// 1. Inner forward-declared classes (pimpl pattern)
// 2. External opaque types from other headers (like CUDA types)
// 3. C-style opaque typedef declarations (like CvCapture, CvVideoWriter from OpenCV)

#include <cstddef>
#include <cstdint>

// External opaque types (like CUstream_st, CUevent_st from CUDA)
// These are forward-declared structs that are never fully defined
struct ExternalOpaqueA;
struct ExternalOpaqueB;

// Typedefs to pointers (like cudaStream_t = CUstream_st*)
typedef ExternalOpaqueA* OpaqueHandleA;
typedef ExternalOpaqueB* OpaqueHandleB;

// C-style opaque typedef declarations (like CvCapture, CvVideoWriter from OpenCV)
// These combine a forward declaration with a typedef in one statement.
// Both should be registered with Rice.
typedef struct OpaqueTypeC OpaqueTypeC;
typedef struct OpaqueTypeD OpaqueTypeD;

namespace Outer
{
  namespace Inner
  {
    // Smart pointer template for testing Ptr<Impl> pattern
    template<typename T>
    class Ptr
    {
    public:
      T* ptr;
    };

    class PimplClass
    {
    public:
      PimplClass();

      // Forward-declared Impl struct (incomplete type)
      struct Impl;

      // This method should be SKIPPED (returns pointer to incomplete type)
      Impl* getImpl() const { return p; }

      // This method should be included (returns complete type)
      bool empty() const { return !p; }

    protected:
      Impl* p;
    };

    // Test with public Impl* field - should also be skipped
    class PimplClassWithPublicField
    {
    public:
      PimplClassWithPublicField();

      struct Impl;

      // This field should be SKIPPED (pointer to incomplete type)
      Impl* impl;

      // This field should be included (complete type)
      int value;
    };

    // Test constructor with Impl* parameter (Issue #31)
    class PimplClassWithConstructor
    {
    public:
      struct Impl;

      // This constructor should be SKIPPED (parameter is pointer to incomplete type)
      PimplClassWithConstructor(Impl* impl, int offset);

      // This constructor should be included (complete types only)
      PimplClassWithConstructor(int value);

      // Default constructor should be included
      PimplClassWithConstructor();

      int getValue() const { return val; }

    private:
      int val;
    };

    // Test field with Ptr<Impl> - template with incomplete type argument (Issue #32)
    class PimplClassWithSmartPtr
    {
    public:
      struct Impl;

      PimplClassWithSmartPtr();

      // This field should be SKIPPED (template with incomplete type argument)
      Ptr<Impl> impl;

      // This field should be included (template with complete type argument)
      Ptr<int> data;

      // This field should be included (complete type)
      int value;
    };

    // Test double-pointer fields with incomplete types
    class PimplClassWithDoublePtr
    {
    public:
      struct Impl;

      PimplClassWithDoublePtr();

      // Double-pointer field to incomplete type
      Impl** ppImpl;

      // Double-pointer to complete type
      int** ppValue;

      // Regular complete type
      int value;
    };

    // Test static fields with incomplete types
    class PimplClassWithStaticFields
    {
    public:
      struct Impl;

      PimplClassWithStaticFields();

      // Static field with incomplete pointer type - should be SKIPPED
      static Impl* staticImplPtr;

      // Static field with template containing incomplete type - should be SKIPPED
      static Ptr<Impl> staticSmartPtr;

      // Static field with complete type - should be included
      static int staticValue;

      // Static field with template containing complete type - should be included
      static Ptr<int> staticData;
    };

    // Test static methods with incomplete types
    class PimplClassWithStaticMethods
    {
    public:
      struct Impl;

      PimplClassWithStaticMethods();

      // Static method returning incomplete pointer type - should be SKIPPED
      static Impl* createImpl();

      // Static method with incomplete pointer parameter - should be SKIPPED
      static void initFromImpl(Impl* impl);

      // Static method returning template with incomplete type - should be SKIPPED
      static Ptr<Impl> getSmartImpl();

      // Static method with complete types - should be included
      static int getValue();

      // Static method with complete parameter - should be included
      static void setValue(int val);
    };

    // Test template instantiation with COMPLETE type argument (like cv::Ptr<DownhillSolver>::create())
    // This is the opposite of the incomplete case - these should be INCLUDED
    class FactoryClass
    {
    public:
      FactoryClass();

      // Static factory method returning Ptr<FactoryClass> - should be INCLUDED
      // (template argument FactoryClass is complete, not forward-declared)
      static Ptr<FactoryClass> create();

      // Instance method returning Ptr<FactoryClass> - should be INCLUDED
      Ptr<FactoryClass> clone() const;

      // Field with Ptr<FactoryClass> - should be INCLUDED
      Ptr<FactoryClass> parent;

      // Method taking Ptr<FactoryClass> parameter - should be INCLUDED
      void setParent(Ptr<FactoryClass> p);

      int getValue() const { return val; }

    private:
      int val;
    };

    // Test nested class scenario - Ptr<Outer> from within Outer should work
    class OuterWithFactory
    {
    public:
      class InnerFactory
      {
      public:
        // Returns Ptr to the outer class - should be INCLUDED
        static Ptr<OuterWithFactory> createOuter();
      };

      OuterWithFactory();
      int data;
    };

    // Test methods returning built-in typedefs (like uint64_t)
    // These should NOT be flagged as incomplete types (Issue #33)
    class TypedefReturnClass
    {
    public:
      TypedefReturnClass();

      // Methods returning built-in typedefs - should be INCLUDED
      // (uint64_t is a typedef to unsigned long long, not an incomplete type)
      uint64_t getCount() const { return count; }
      int64_t getSignedCount() const { return signedCount; }
      std::size_t getSize() const { return sz; }

      // Method returning void - should be INCLUDED
      void reset() { count = 0; }

      // Field with typedef type - should be INCLUDED
      uint64_t count;
      int64_t signedCount;
      std::size_t sz;
    };

    // Test methods returning references to incomplete types (Issue #35)
    // Like cv::dnn::Net::getImplRef() returning Impl&
    class PimplClassWithRefReturn
    {
    public:
      struct Impl;

      PimplClassWithRefReturn();

      // Method returning lvalue reference to incomplete type - should be SKIPPED
      Impl& getImplRef();

      // Method returning const lvalue reference to incomplete type - should be SKIPPED
      const Impl& getImplConstRef() const;

      // Method returning rvalue reference to incomplete type - should be SKIPPED
      Impl&& getImplRvalueRef();

      // Method returning reference to complete type - should be INCLUDED
      int& getValueRef() { return val; }

      // Method returning const reference to complete type - should be INCLUDED
      const int& getValueConstRef() const { return val; }

      // Regular method - should be INCLUDED
      int getValue() const { return val; }

    private:
      Impl* p;
      int val;
    };

    // =========================================================================
    // External opaque types tests (like cv::cuda::StreamAccessor with cudaStream_t)
    // =========================================================================

    // Class that wraps external opaque types (like cv::cuda::StreamAccessor)
    class ExternalOpaqueWrapper
    {
    public:
      // Methods using external opaque pointer types via typedef
      // Rice needs to register ExternalOpaqueA and ExternalOpaqueB
      static OpaqueHandleA getHandleA();
      static OpaqueHandleB getHandleB();

      // Methods taking external opaque types as parameters
      static void useHandleA(OpaqueHandleA handle);
      static void useHandleB(OpaqueHandleB handle);

      // Method returning raw pointer to external opaque type
      static ExternalOpaqueA* getRawA();
      static ExternalOpaqueB* getRawB();
    };

    // Template that uses external opaque type as argument (like cv::DefaultDeleter<CvVideoWriter>)
    template<typename T>
    class Deleter
    {
    public:
      void operator()(T* obj) const;
    };

    // Class using Deleter with external opaque type
    class DeleterUser
    {
    public:
      DeleterUser();

      // Field with template containing external opaque type
      Deleter<ExternalOpaqueA> deleterA;

      // Method returning template with external opaque type
      Deleter<ExternalOpaqueB> getDeleterB();
    };
  }
}
