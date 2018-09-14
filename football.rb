require 'net/http'
require 'nokogiri'
require 'json'
require 'csv'
require 'yaml'
require 'optparse'

class FootballProjections
	def initialize(fantasyfootballnerdkey, week, position)
		@allplayers = {}
		@fantasyfootballnerdurls = {
			position => "https://www.fantasyfootballnerd.com/service/weekly-rankings/xml/#{fantasyfootballnerdkey}/#{position}",
		}

		@nflurls = {
			position => "http://api.fantasy.nfl.com/v1/players/scoringleaders?position=#{position}&sort=projectedPts&week=#{week}",
		}
	end

	def getStats(position, getNFL = 1, getFFN = 1, getFantasyData = 1)
		@allplayers[position] = {}
		
		getNFLStats(position) if getNFL
		getFantasyFootballNerdStats(position) if getFFN
	end
	
	def getNFLStats(position)
		uri = URI(@nflurls[position])
		res = Net::HTTP.get_response(uri)
		xml_doc  = Nokogiri::Slop res.body
		players = xml_doc.scoringLeaders.scoringLeader.players
		
		players.player.each do |player|
			playerFName = player.attr("firstName")
			playerLName = player.attr("lastName")
			playername = "#{playerFName} #{playerLName}"

			@allplayers[position][playername] = {} if @allplayers[position][playername].nil?
			
			@allplayers[position][playername] = {}
			@allplayers[position][playername]['team'] = player.attr("teamAbbr")
			@allplayers[position][playername]['vs'] = player.attr("opponentTeamAbbr")
			@allplayers[position][playername]['gameTime'] = player.attr("status")
			@allplayers[position][playername]['projectedPointsNFL'] = player.attr("projectedPts")
		end
	end

	def getFantasyFootballNerdStats(position)
		uri = URI(@fantasyfootballnerdurls[position])
		res = Net::HTTP.get_response(uri)
		xml_doc  = Nokogiri::Slop res.body
		players = xml_doc.WeeklyRankings.Rankings.Player
		players.each do |player|
			playername = player.search('name').text

			@allplayers[position][playername] = {} if @allplayers[position][playername].nil?
			
			@allplayers[position][playername]['team'] = player.search('team').text
			@allplayers[position][playername]['projectedPointsFFNStandard'] = player.search('standard').text
			@allplayers[position][playername]['projectedPointsFFNStandardLow'] = player.search('standardLow').text
			@allplayers[position][playername]['projectedPointsFFNStandardHigh'] = player.search('standardHigh').text
			@allplayers[position][playername]['weightedPointsFFNStandard'] = ((player.search('standardHigh').text.to_f + player.search('standardLow').text.to_f + player.search('standardHigh').text.to_f)/3).round(2)
			@allplayers[position][playername]['injury'] = player.search('injury').text
			@allplayers[position][playername]['practiceStatus'] = player.search('practiceStatus').text
			@allplayers[position][playername]['gameStatus'] = player.search('gameStatus').text
		end
	end
end

options = {}
optparse = OptionParser.new do |opts|
	opts.banner = "Usage: football.rb [options]"

	opts.on('-p', '--position NAME', 'Position (can only be QB, RB, or WR)') { |v| options[:position] = v }
	opts.on('-j', '--json BOOL', 'Print to JSON') { |v| options[:print] = v }
	opts.on('-w', '--week INT', 'Week Number') { |v| options[:week] = v.to_i }
end.parse!

timestamp = Time.new
time = timestamp.strftime("%Y-%m-%d %H:%M:%S (%Z)")

if config = YAML.load_file('config.yaml')
	fantasyFootballNerdApiKey = config['fantasyFootballNerd']['apiKey']
elsif ENV['fantasyFootballNerdApiKey']
	fantasyFootballNerdApiKey = ENV['fantasyFootballNerdApiKey']
end
config = YAML.load_file('config.yaml') # loading config info for database

football = FootballProjections.new(fantasyFootballNerdApiKey, options[:week], options[:position])
football.getStats(options[:position])
allplayers = football.instance_variable_get(:@allplayers)
allplayers['created_at'] = time

if options[:print]
	File.open("tmp/#{options[:position]}.json", "w+") do |file|
		file.write(allplayers.to_json)
	end
end
