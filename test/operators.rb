class Operators
	attr_reader :value

	def initialize
		@value = 3
	end

	def call()
		puts "yes"
		#	self.value ^ other.value
	end
end

o1 = Operators.new
o2 = Operators.new
o1.()
