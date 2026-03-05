// Top-level union
union SimpleUnion {
  int i;
  double d;
};

// Union with embedded union (tests visit_union dispatching)
union OuterUnion {
  union InnerUnion {
    int x;
    double y;
  } inner;
  long z;
};

// Union with embedded struct
union MixedUnion {
  struct MixedData {
    int a;
    int b;
  } data;
  long raw;
};
