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
end
