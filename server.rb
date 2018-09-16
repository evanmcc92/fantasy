require 'sinatra'

class App < Sinatra::Base
	get('/') do
		send_file 'index.html'
	end

	['QB','RB','WR','TE','DEF','K'].each do|p|
		get("/tmp/#{p}.json") do
			send_file "./tmp/#{p}.json"
		end
	end
end