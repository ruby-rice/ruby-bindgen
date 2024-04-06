#include <inheritance.hpp>
#include "inheritance-rb.hpp"

using namespace Rice;



extern "C"
void Init_Inheritance()
{
  Enum<NotificationType> rb_cNotificationType = define_enum<NotificationType>("NotificationType", rb_cObject).
    define_value("Email", NotificationType::Email).
    define_value("Push", NotificationType::Push);
  
  Class rb_cNotification = define_class<Notification>("Notification").
    define_method<NotificationType(Notification::*)()>("notification_type", &Notification::notificationType).
    define_method<int(Notification::*)()>("message", &Notification::message);
  
  Class rb_cEmailNotification = define_class<EmailNotification, Notification>("EmailNotification").
    define_method<int(EmailNotification::*)()>("message", &EmailNotification::message);
  
  Class rb_cPushNotification = define_class<PushNotification, Notification>("PushNotification").
    define_method<int(PushNotification::*)()>("message", &PushNotification::message);

}