namespace ForwardDeclaredClasses
{
  class ActivationLayer;

  class Layer
  {
  public:
    virtual ~Layer() = default;

    bool enabled() const
    {
      return true;
    }
  };

  class Net
  {
  public:
    void setActivation(ActivationLayer* layer);
  };
}
