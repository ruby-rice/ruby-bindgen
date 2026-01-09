// Test case for pimpl pattern - methods/fields returning incomplete types should be skipped

#include <cstdint>

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
  }
}
