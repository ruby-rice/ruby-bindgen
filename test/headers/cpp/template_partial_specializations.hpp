#pragma once

#include <tuple>

namespace Tests {
struct Context {};

template<typename T>
struct Array {};

struct Mat {};
struct Token {};

namespace detail {
template<class T>
struct get_in
{
  static T get(Context& ctx, int idx);
};

template<typename U>
struct get_in<Array<U>>
{
  static const U& get(Context& ctx, int idx);
};

template<>
struct get_in<Array<Token>> : public get_in<Array<Mat>>
{
};

template<class T>
struct get_out;

template<typename U>
struct get_out<Array<U>>
{
  static U& get(Context& ctx, int idx);
};

template<>
struct get_out<Array<Token>> : public get_out<Array<Mat>>
{
};

template<typename, typename, typename>
struct CallHelper;

template<typename Impl, typename... Ins, typename... Outs>
struct CallHelper<Impl, std::tuple<Ins...>, std::tuple<Outs...>>
{
  template<typename... Inputs>
  struct call_and_postprocess
  {
    static void call(Inputs... inputs);
  };
};
} // namespace detail

struct FileStorage
{
  struct Impl;
};

template<typename Impl, typename K>
struct KernelImpl
{
  static int backend();
  static int kernel();
};
} // namespace Tests
