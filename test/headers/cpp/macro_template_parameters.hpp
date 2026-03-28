namespace Tests
{
  namespace Internal
  {
    #define TEST_CREATE_MEMBER_CHECK(X) \
    template<typename T> class CheckMember_##X \
    { \
    public: \
      typedef CheckMember_##X type; \
      enum { value = 1 }; \
    };

    TEST_CREATE_MEMBER_CHECK(fmt)
    TEST_CREATE_MEMBER_CHECK(type)
  }

  template<typename T, bool available = Internal::CheckMember_type<T>::value>
  class SafeType
  {
  public:
    enum { value = available };
  };

  template<typename T, bool available = Internal::CheckMember_fmt<T>::value>
  class SafeFmt
  {
  public:
    enum { value = available };
  };
}
