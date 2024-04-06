#include <rice/rice.hpp>

Enum<NotificationType> rb_cNotificationType = define_enum<NotificationType>("NotificationType", rb_cObject).
  define_value("email", 0).
  define_value("push", 1);

Class rb_cNotification = define_class<Notification>("Notification").
  define_method("notification_type", &Notification::notificationType).
  define_method("message", &Notification::message);

Class rb_cEmailNotification = define_class<EmailNotification, Notification>("EmailNotification").
  define_method("message", &EmailNotification::message);

Class rb_cPushNotification = define_class<PushNotification, Notification>("PushNotification").
  define_method("message", &PushNotification::message);