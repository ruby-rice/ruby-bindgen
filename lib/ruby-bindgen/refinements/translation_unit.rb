module FFI
	module Clang
		class TranslationUnit
			def includes
				result = Set.new
				adapter = Proc.new do |included_file, inclusion_stack, include_len, unused|
					cur_ptr = inclusion_stack
					include_len.times do
						location = SpellingLocation.new(Lib::CXSourceLocation.new(cur_ptr))
						if location.from_main_file?
							cursor = self.cursor(location)
							result << cursor.extent.text
						end
						cur_ptr += Lib::CXSourceLocation.size
 				  end
				end

				Lib.get_inclusions(self, adapter, nil)
				result.to_a
			end
		end
	end
end