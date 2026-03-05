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

// Union with callback function pointer field
union CallbackUnion {
  void (*on_event)(int code, const char *message);
  void *raw;
};

// Union with embedded struct
union MixedUnion {
  struct MixedData {
    int a;
    int b;
  } data;
  long raw;
};
