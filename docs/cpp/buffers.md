# Buffers and Pointers

`ruby-bindgen` automatically wraps some pointer parameters and return types. For details on using buffers and pointers from Ruby, see the Rice documentation on [Buffers](https://ruby-rice.github.io/4.x/bindings/buffers/) and [Pointers](https://ruby-rice.github.io/4.x/bindings/pointers/).

Pointers to most fundamental types (`int*`, `double*`, `unsigned char*`, `void*`, etc.) and double pointers (`T**`) are automatically wrapped using Rice's `ArgBuffer` and `ReturnBuffer` classes:

```cpp
void processData(int* data, int size);           // ArgBuffer("data")
void getMinMax(double* min, double* max);        // Out parameters via ArgBuffer
int* createBuffer(int size);                     // ReturnBuffer
void processArrays(float** matrices, int count); // Double pointer via ArgBuffer
```

`char*` and `wchar_t*` are treated as strings rather than raw buffers, so they do **not** use `ArgBuffer` or `ReturnBuffer`:

```cpp
void processCharBuffer(char* buffer, int length);  // Arg("buffer")
```

This distinction matters for APIs that mix byte buffers and strings:

- `unsigned char*` is treated as a byte buffer
- `char*` / `wchar_t*` are treated as string pointers
- Any `T**` is treated as a buffer-style pointer, even when `T` is a class type
