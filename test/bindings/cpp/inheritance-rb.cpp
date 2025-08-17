#include <inheritance.hpp>
#include "inheritance-rb.hpp"

using namespace Rice;

Rice::Class rb_cEmailNotification;
Rice::Class rb_cNotification;
Rice::Class rb_cPushNotification;



void Init_Inheritance()
{
  Enum<NotificationType> rb_cNotificationType = define_enum<NotificationType>("NotificationType").
    define_value("Email", NotificationType::Email).
    define_value("Push", NotificationType::Push);
  
  rb_cNotification = define_class<Notification>("Notification").
    define_method("notification_type", &Notification::notificationType).
    define_method("message", &Notification::message);
  
  rb_cEmailNotification = define_class<EmailNotification, Notification>("EmailNotification").
    define_method("message", &EmailNotification::message);
  
  rb_cPushNotification = define_class<PushNotification, Notification>("PushNotification").
    define_method("message", &PushNotification::message);

}