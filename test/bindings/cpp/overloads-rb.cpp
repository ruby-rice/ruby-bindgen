#include <overloads.hpp>
#include "overloads-rb.hpp"

using namespace Rice;

void Init_Overloads()
{
  Module rb_mOuter = define_module("Outer");

  Module rb_mOuterInner = define_module_under(rb_mOuter, "Inner");

  Rice::Data_Type<Outer::Inner::Queue> rb_cOuterInnerQueue = define_class_under<Outer::Inner::Queue>(rb_mOuterInner, "Queue").
    define_constructor(Constructor<Outer::Inner::Queue>()).
    define_method<void(Outer::Inner::Queue::*)()>("finish", &Outer::Inner::Queue::finish);

  Rice::Data_Type<Outer::Inner::Device> rb_cOuterInnerDevice = define_class_under<Outer::Inner::Device>(rb_mOuterInner, "Device").
    define_constructor(Constructor<Outer::Inner::Device>());

  Rice::Data_Type<Outer::Inner::ExecutionContext> rb_cOuterInnerExecutionContext = define_class_under<Outer::Inner::ExecutionContext>(rb_mOuterInner, "ExecutionContext").
    define_constructor(Constructor<Outer::Inner::ExecutionContext>()).
    define_method<Outer::Inner::ExecutionContext(Outer::Inner::ExecutionContext::*)(const Outer::Inner::Queue&) const>("clone_with_new_queue", &Outer::Inner::ExecutionContext::cloneWithNewQueue,
      Arg("q")).
    define_method<Outer::Inner::ExecutionContext(Outer::Inner::ExecutionContext::*)() const>("clone_with_new_queue", &Outer::Inner::ExecutionContext::cloneWithNewQueue).
    define_singleton_function<Outer::Inner::ExecutionContext(*)(const Outer::Inner::Device&)>("create", &Outer::Inner::ExecutionContext::create,
      Arg("device")).
    define_singleton_function<Outer::Inner::ExecutionContext(*)(const Outer::Inner::Device&, const Outer::Inner::Queue&)>("create", &Outer::Inner::ExecutionContext::create,
      Arg("device"), Arg("queue"));

  Rice::Data_Type<Outer::Inner::KernelArg> rb_cOuterInnerKernelArg = define_class_under<Outer::Inner::KernelArg>(rb_mOuterInner, "KernelArg").
    define_constructor(Constructor<Outer::Inner::KernelArg>()).
    define_attr("flags", &Outer::Inner::KernelArg::flags).
    define_singleton_function<Outer::Inner::KernelArg(*)(const char*)>("constant", &Outer::Inner::KernelArg::Constant,
      Arg("data")).
    define_singleton_function<Outer::Inner::KernelArg(*)(int)>("read_only", &Outer::Inner::KernelArg::ReadOnly,
      Arg("m")).
    define_singleton_function<Outer::Inner::KernelArg(*)(int, int)>("read_only", &Outer::Inner::KernelArg::ReadOnly,
      Arg("m"), Arg("wscale"));
}