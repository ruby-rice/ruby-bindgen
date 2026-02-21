#include <inheritance.hpp>
#include "inheritance-rb.hpp"

using namespace Rice;



void Init_Inheritance()
{
  Enum<NotificationType> rb_cNotificationType = define_enum<NotificationType>("NotificationType").
    define_value("Email", NotificationType::Email).
    define_value("Push", NotificationType::Push);

  Rice::Data_Type<Notification> rb_cNotification = define_class<Notification>("Notification").
    define_method<NotificationType(Notification::*)()>("notification_type", &Notification::notificationType).
    define_method<std::string(Notification::*)()>("message", &Notification::message);

  Rice::Data_Type<EmailNotification> rb_cEmailNotification = define_class<EmailNotification, Notification>("EmailNotification").
    define_method<std::string(EmailNotification::*)()>("message", &EmailNotification::message);

  Rice::Data_Type<PushNotification> rb_cPushNotification = define_class<PushNotification, Notification>("PushNotification").
    define_method<std::string(PushNotification::*)()>("message", &PushNotification::message);

}
