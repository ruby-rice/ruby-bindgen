#include <string>

enum class NotificationType
{
    Email,
    Push
};

class Notification
{
    public:
        virtual ~Notification() = default;
        virtual NotificationType notificationType() = 0;
        virtual std::string message() = 0;
};

class EmailNotification : public Notification
{
    public:
        std::string message() override;
};

class PushNotification : public Notification
{
    public:
        std::string message() override;
};
