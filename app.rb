require 'sinatra'
require_relative './models/footballprojections'

class App < Sinatra::Application
	before do 
		@football = FootballProjections.new(ENV['fantasyFootballNerdApiKey'])
		@allplayers = @football.getStats()
	end

	get('/') do
		erb :tabletemplate, :layout => :pagelayout
	end
end