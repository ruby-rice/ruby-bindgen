// Test case for pimpl pattern - methods/fields returning incomplete types should be skipped

namespace Outer
{
  namespace Inner
  {
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
  }
}
