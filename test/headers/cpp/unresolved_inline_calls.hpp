#pragma once

namespace Tests {
namespace Broken {
}

class Logger
{
public:
  static int info();
};

namespace Utils {
int id();
}

template<typename T>
struct Params
{
  int backend() const { return Tests::Broken::backend(); }
  int logger() const { return Tests::Logger::info(); }
  int utility() const { return Utils::id(); }
  int ok() const { return 1; }
};
}
