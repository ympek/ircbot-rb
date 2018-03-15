require 'socket'


# this class will be responsible for logging
# interface gives away just one method - log 
class Logger
	def initialize
		@log_buffer = []
		@file_handle = File.open('logz', 'w+')
	end

	def log(str)
		@file_handle.puts(str)
	end

protected
	def actual
	end
end

class IRCBot
	@@modules = []
	
	def initialize(host, port, channel, nick)
		@socket = TCPSocket.new(host, port)
		@channel = channel
		@nick = nick
		@socket.puts "USER #@nick #@nick #@nick #@nick"
		@socket.puts "NICK #@nick"
		@socket.puts "JOIN #@channel"

		@logger = Logger.new
	end

    def load_or_reload_modules
		@@modules.clear
		Dir.foreach("bot_modules") do |m|
			if m !~ /^\./ and not m.include? '~'
				begin
					load "bot_modules/" + m
					@@modules << m.chomp!('.rb').capitalize!
				rescue StandardError
					send_text "Nie zaladowalem modulu " + m + ". Jego kod jest niepoprawny."	
				end
			end
		end
		@@modules.each do |m|
			ObjectSpace.each_object(Module) do |x|
				if x.name == m
					self.extend(x)
					send_text "Zaladowalem pomyslnie modul: " + m
				end	
			end
		end
	end
	
	def privmsg?(str)
		# TODO replace with more sophisticated regex			
		str =~ /PRIVMSG/
	end

	def ping_request?(str)
		str[0..3] == "PING"
	end
	
	def run!
		load_or_reload_modules()
		loop do
			str = @socket.gets
			if str != nil
				puts str

				# str might be a PING request. lets cover it right there
				if ping_request?(str)
					pong_server(str[6..-1])
				end

				if privmsg?(str)
					@logger.log(str)
				end
				
				idx = str.index(":", 3)
				str = str[idx + 1, str.size] if idx
				if str =~ /^!bot[[:space:]]/
					line = str.chomp.split
					if line.size > 1
						line.shift
						case line[0]
							when 'reload' then load_or_reload_modules
							else do_command(line.shift, line.shift, line)
						end
					else send_text "Co znowu?"	
					end
				end
			end
		end
	end

	# definitely needs refactoring
	def do_command(mod, method, *args)
		bool = nil
		begin
			ObjectSpace.each_object(Module) do |x|
				if x.name == mod.capitalize
					begin
						bool = true
						self.send(method, args)
						send_text args[0].to_s
					rescue ArgumentError
						bool = true
						self.send(method)
					end
				end
			end	
		rescue StandardError
			send_text "Co?"
		end
	end
    def method_missing(name)
        @socket.puts "PRIVMSG #@channel :Nie potrafie wykonac tego polecenia (#{name}), wybacz."
    end
    def send_text(msg)
        @socket.puts "PRIVMSG #@channel :#{msg}"
	end
	def pong_server(server_name)
		@socket.puts "PONG :" + server_name
	end
    def ping
        send_text("pong")
    end
end

bocina = IRCBot.new('irc.freenode.net', 6667, '#paruwasoft', 'bott')
bocina.run!