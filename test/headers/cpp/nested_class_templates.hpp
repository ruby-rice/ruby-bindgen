namespace Tests
{
    template<typename T>
    class Allocator
    {
    public:
        typedef T value_type;

        template<typename U>
        class rebind
        {
        public:
            typedef Allocator<U> other;
        };
    };

    typedef Allocator<int> Allocatori;
}
