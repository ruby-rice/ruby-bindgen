#pragma once

namespace Guards
{
  // Class with methods, constructors, and anonymous enum constants
  class MyClass
  {
  public:
    MyClass();
    MyClass(int x, bool flag);  // versioned constructor (by signature)

    void existingMethod();
    void newMethod();  // versioned

    // Overloaded method — only the bool overload is versioned
    void overloaded(int x);
    void overloaded(int x, bool flag);

    // Anonymous enum constants — some versioned
    enum
    {
      EXISTING_CONST = 1,
      NEW_CONST = 2  // versioned
    };
  };

  // Namespace-level anonymous enum constants
  enum
  {
    EXISTING_FLAG = 0,
    NEW_FLAG = 1  // versioned
  };

  // Free function — versioned
  inline void newFunction(int x) {}

  // Type introduced in a newer version
  class HalfFloat
  {
  public:
    float value;
  };

  // Class template with existing specializations
  template<typename T>
  class DataType
  {
  public:
    static int depth() { return 0; }
  };

  template<> class DataType<int>
  {
  public:
    static int depth() { return 1; }
  };

  // Template specialization using versioned type — version-guarded
  template<> class DataType<HalfFloat>
  {
  public:
    static int depth() { return 2; }
  };

  // Function template with explicit specialization using versioned type
  template<typename T>
  inline T saturate_cast(int v) { return T(); }

  template<>
  inline HalfFloat saturate_cast<HalfFloat>(int v) { HalfFloat h; h.value = (float)v; return h; }
}
