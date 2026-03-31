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

  def test_preserves_dependent_typedef_inside_pointer_types
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace Tests {
        template<typename T>
        struct Holder {
          typedef T value_type;
          explicit Holder(const value_type* values);
        };
      }
    CPP

    class_template = find_cursor(parsed.translation_unit.cursor, :cursor_class_template, "Holder")
    constructor = class_template.find_by_kind(false, :cursor_constructor).first
    param = constructor.find_by_kind(false, :cursor_parm_decl).first

    spelled = collaborators[:type_speller].type_spelling(param.type)
    qualified = collaborators[:type_speller].qualify_class_template_typedefs(spelled, class_template)

    assert_equal "const typename Tests::Holder<T>::value_type *", qualified
  end

  def test_preserves_parameter_pack_names_in_dependent_typedef_spellings
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace Tests {
        template<typename... Ts>
        struct Holder {
          using StorageT = Holder<Ts...>;
          using Map = StorageT;

          StorageT& storage();
          const Map& getStorage() const;
        };
      }
    CPP

    class_template = find_cursor(parsed.translation_unit.cursor, :cursor_class_template, "Holder")
    storage = class_template.find_by_kind(false, :cursor_cxx_method).find { |cursor| cursor.spelling == "storage" }
    refute_nil storage
    get_storage = class_template.find_by_kind(false, :cursor_cxx_method).find { |cursor| cursor.spelling == "getStorage" }
    refute_nil get_storage

    assert_equal "typename Tests::Holder<Ts...>::StorageT &",
                 collaborators[:type_speller].type_spelling(storage.type.result_type)
    assert_equal "const typename Tests::Holder<Ts...>::Map &",
                 collaborators[:type_speller].type_spelling(get_storage.type.result_type)
  end
end
