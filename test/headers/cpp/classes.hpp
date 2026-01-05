const int GLOBAL_CONSTANT = 1;
int globalVariable = 2;

namespace Outer
{
  const int NAMESPACE_CONSTANT = 3;
  int namespaceVariable = 4;

  class BaseClass
  {
  };

  class MyClass : public BaseClass
  {
    public:
        static const int SOME_CONSTANT = 42;
        static int static_field_one;
        static bool staticMethodOne();

        MyClass();
        MyClass(int a);
        ~MyClass();

        void methodOne(int a);
        void methodTwo(int a, bool b);

        void overloaded(int a);
        void overloaded(bool a);

        int field_one = 3;

    private:
        int field_two = 4;
        void methodThree();
  };

  namespace Inner
  {
    class ContainerClass
    {
    public:
        class Callback
        {
        public:
          virtual ~Callback();
          virtual bool compute() const;
        };
        Callback callback;

        struct Config
        {
        public:
            bool enable;
        };
        Config config;

        enum GridType
        {
          SYMMETRIC_GRID, ASYMMETRIC_GRID
        };
        GridType gridType;
    };
  }
}