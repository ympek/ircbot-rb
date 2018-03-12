module Helloworld
	def hello(args)
		send_text 'hello' + args[0].to_s
	end
end
