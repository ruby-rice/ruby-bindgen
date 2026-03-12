// Top-level union (no namespace) - should use define_class, not define_class_under
union TopLevelUnion
{
  int i;
  float f;
};

namespace Unions
{
  union SimpleUnion
  {
    int i;
    double d;
  };

  union NestedUnion
  {
    union Inner
    {
      int x;
      double y;
    } inner;
    long z;
  };

  union UnionWithStruct
  {
    struct Data
    {
      int a;
      int b;
    } data;
    long raw;
  };

  // Union with an anonymous embedded struct - visit_struct returns nil
  // for anonymous types without a definer, which must not crash.
  union UnionWithAnonymousStruct
  {
    struct
    {
      int x;
      int y;
    };
    long raw;
  };

  // Union with a function pointer field — must not crash the Rice generator.
  // Rice has no visit_callback; these fields should be silently skipped.
  union UnionWithCallback
  {
    void (*handler)(int status);
    void* raw;
  };
}
