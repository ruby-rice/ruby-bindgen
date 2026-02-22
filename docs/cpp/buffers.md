# Buffers and Pointers

`ruby-bindgen` automatically wraps pointer parameters and return types. For details on using buffers and pointers from Ruby, see the Rice documentation on [Buffers](https://ruby-rice.github.io/4.x/bindings/buffers/) and [Pointers](https://ruby-rice.github.io/4.x/bindings/pointers/).

Pointers to fundamental types (`int*`, `double*`, `char*`, `void*`, etc.) and double pointers (`T**`) are automatically wrapped using Rice's `ArgBuffer` and `ReturnBuffer` classes:

```cpp
void processData(int* data, int size);           // ArgBuffer("data")
void getMinMax(double* min, double* max);        // Out parameters via ArgBuffer
int* createBuffer(int size);                     // ReturnBuffer
void processArrays(float** matrices, int count); // Double pointer via ArgBuffer
```

This enables Ruby code to:
- Pass buffers of data to C++ functions
- Use out parameters for returning values
- Work with arrays of pointers
