// Test case for pimpl pattern - methods/fields returning incomplete types should be skipped

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
  }
}
