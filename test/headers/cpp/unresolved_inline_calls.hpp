#pragma once

namespace Tests {
namespace Broken {
}

template<typename T>
struct Params
{
  int backend() const { return Tests::Broken::backend(); }
  int ok() const { return 1; }
};
}
