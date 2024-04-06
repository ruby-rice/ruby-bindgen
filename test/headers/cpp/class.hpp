namespace MyNamespace
{
  class MyClass
  {
    public:
        static int SOME_CONSTANT;
        static int static_field_one;
        static bool staticMethodOne();

        MyClass();
        ~MyClass();

        void methodOne(int a);
        void methodTwo(int a, bool b);

        int field_one = 3;

    private:
        int field_two = 4;
        void methodThree();
  };

  class EmptyClass
  {
  };
}