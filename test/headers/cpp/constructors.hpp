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

class CopyMoveConstructors
{
public:
    CopyMoveConstructors() = default;
    CopyMoveConstructors(const CopyMoveConstructors& other);
    CopyMoveConstructors(CopyMoveConstructors&& other);
};

// Test template class constructor signature should be Constructor<TemplateClass<T>>
template<typename T>
class TemplateConstructor
{
public:
    TemplateConstructor();
    TemplateConstructor(T value);
};

typedef TemplateConstructor<int> TemplateConstructorInt;