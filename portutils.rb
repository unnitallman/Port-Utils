require 'socket'

module PortUtils
	def self.kill(port)
		begin
			pname,pid = get_pid(port) 
			puts "Process with name #{pname} and pid #{pid} is using port #{port}"
			kill_with_pid(pid)
		rescue 
			puts "port #{port} is free" 
		end
	end

	def self.kill_with_pid(pid)
		`kill -9 #{pid}`
	end

	def self.get_pid(port)
		s = `lsof -i :#{port}`.split("\n").last.split(" ")
		s[0..1]
	end

	def self.port_free?(port)
		begin
			server = TCPServer.new('127.0.0.1', port)
		rescue => e
			return !e.message.include?("Address already in use")
		end
		true
	end

	def self.get_free_port
		server = TCPServer.new('127.0.0.1', 0)
		server.addr[1]
	end
end

