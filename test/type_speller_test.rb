# encoding: UTF-8

require_relative './rice_abstract_test'

class TypeSpellerTest < RiceAbstractTest
  def test_qualifies_class_static_members
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace Tests {
        template<typename T, int Size> struct FixedBuffer {};

        template<int N>
        struct StaticSized {
          static constexpr int Size = N;
        };
      }
    CPP

    class_cursor = find_cursor(parsed.translation_unit.cursor, :cursor_class_template, "StaticSized")
    assert_equal "FixedBuffer<int, Tests::StaticSized<N>::Size>",
                 collaborators[:type_speller].qualify_class_static_members("FixedBuffer<int, Size>", class_cursor)
  end

  def test_preserves_public_std_exception_ptr_alias
    parsed, collaborators = parse_cpp(<<~CPP)
      #include <exception>

      namespace Tests {
        class Example {
        public:
          void setException(std::exception_ptr exception);
        };
      }
    CPP

    method = find_cursor(parsed.translation_unit.cursor, :cursor_cxx_method, "setException")
    param = method.find_by_kind(false, :cursor_parm_decl).first

    assert_equal "std::exception_ptr", collaborators[:type_speller].type_spelling(param.type)
  end
end
