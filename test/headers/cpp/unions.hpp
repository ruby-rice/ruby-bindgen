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

  // Union with a function pointer field — must not crash the Rice generator.
  // Rice has no visit_callback; these fields should be silently skipped.
  union UnionWithCallback
  {
    void (*handler)(int status);
    void* raw;
  };
}
