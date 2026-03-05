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
}
