// Test cases for overload detection and namespace qualification

namespace Outer
{
  namespace Inner
  {
    // Simple class used as parameter type
    class Queue
    {
    public:
      Queue();
      void finish();
    };

    class Device
    {
    public:
      Device();
    };

    // Test case for partial namespace qualification in method signatures
    // Similar to cv::ocl::OpenCLExecutionContext pattern where parameters
    // use partial namespace like "ocl::Queue" instead of "cv::ocl::Queue"
    class ExecutionContext
    {
    public:
      ExecutionContext();

      // Method with parameter type that uses partial namespace (Inner::Queue)
      // Generator should fully qualify as Outer::Inner::Queue in method signature
      ExecutionContext cloneWithNewQueue(const Inner::Queue& q) const;

      // Overload to force signature generation
      ExecutionContext cloneWithNewQueue() const;

      // Static function with partial namespace parameter
      static ExecutionContext create(const Inner::Device& device);
      static ExecutionContext create(const Inner::Device& device, const Inner::Queue& queue);
    };

    // Test case for function template overloads
    // Similar to cv::ocl::KernelArg::Constant pattern where there's both
    // a regular function and a template overload
    class KernelArg
    {
    public:
      int flags;

      // Static function with template overload - requires explicit type cast
      static KernelArg Constant(const char* data);

      // Template overload - should cause Constant to need explicit signature
      template<typename T>
      static KernelArg Constant(const T* arr, int n)
      {
        return KernelArg();
      }

      // Regular overloaded functions (non-template)
      static KernelArg ReadOnly(int m);
      static KernelArg ReadOnly(int m, int wscale);
    };
  }
}
