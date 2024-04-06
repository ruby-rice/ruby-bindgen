class ImplicitConstructor
{
};

class DefaultConstructor
{
public:
    DefaultConstructor() = default;
};

class DeleteConstructor
{
public:
    DeleteConstructor() = delete;
};

class OverloadedConstructors
{
public:
    OverloadedConstructors();
    OverloadedConstructors(int a);
};