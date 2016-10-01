require 'net/http'
require 'nokogiri'
require 'json'
require 'csv'
require 'yaml'
require 'optparse'

class FootballProjections
	def initialize(fantasyfootballnerdkey)
		@allplayers = {}
		fantasyfootballnerdkey = 
		@fantasyfootballnerdurls = {
			"QB" => "http://www.fantasyfootballnerd.com/service/weekly-rankings/xml/#{fantasyfootballnerdkey}/QB",
			"WR" => "http://www.fantasyfootballnerd.com/service/weekly-rankings/xml/#{fantasyfootballnerdkey}/WR",
			"RB" => "http://www.fantasyfootballnerd.com/service/weekly-rankings/xml/#{fantasyfootballnerdkey}/RB",
			"TE" => "http://www.fantasyfootballnerd.com/service/weekly-rankings/xml/#{fantasyfootballnerdkey}/TE",
			"DEF" => "http://www.fantasyfootballnerd.com/service/weekly-rankings/xml/#{fantasyfootballnerdkey}/DEF",
		}

		@nflurls = {
			'QB' => "http://api.fantasy.nfl.com/v1/players/scoringleaders?position=QB&sort=projectedPts",
			'RB' => "http://api.fantasy.nfl.com/v1/players/scoringleaders?position=RB&sort=projectedPts",
			'WR' => "http://api.fantasy.nfl.com/v1/players/scoringleaders?position=WR&sort=projectedPts",
			'TE' => "http://api.fantasy.nfl.com/v1/players/scoringleaders?position=TE&sort=projectedPts",
			'DEF' => 'http://api.fantasy.nfl.com/v1/players/scoringleaders?position=DEF&sort=projectedPts',
		}

		@fanstasydataurls = {
			'QB' => 'https://fantasydata.com/nfl-stats/fantasy-football-weekly-projections.aspx?fs=0&stype=0&sn=0&scope=1&w=3&ew=3&s=&t=0&p=1&st=FantasyPoints&d=1&ls=&live=false&pid=false&minsnaps=4',
			'RB' => 'https://fantasydata.com/nfl-stats/fantasy-football-weekly-projections.aspx?fs=0&stype=0&sn=0&scope=1&w=3&ew=3&s=&t=0&p=2&st=FantasyPoints&d=1&ls=&live=false&pid=false&minsnaps=4',
			'WR' => 'https://fantasydata.com/nfl-stats/fantasy-football-weekly-projections.aspx?fs=0&stype=0&sn=0&scope=1&w=3&ew=3&s=&t=0&p=3&st=FantasyPoints&d=1&ls=&live=false&pid=false&minsnaps=4',
			'TE' => 'https://fantasydata.com/nfl-stats/fantasy-football-weekly-projections.aspx?fs=0&stype=0&sn=0&scope=1&w=3&ew=3&s=&t=0&p=4&st=FantasyPoints&d=1&ls=&live=false&pid=false&minsnaps=4',
			'DEF' => 'https://fantasydata.com/nfl-stats/fantasy-football-weekly-projections.aspx?fs=0&stype=0&sn=0&scope=1&w=3&ew=3&s=&t=0&p=6&st=FantasyPoints&d=1&ls=&live=false&pid=false&minsnaps=4'
		}
	end

	def getStats(position, getNFL = 1, getFFN = 1, getFantasyData = 1)
		@allplayers[position] = {}
		
		getNFLStats(position) if getNFL
		getFantasyFootballNerdStats(position) if getFFN
		getFantasyDataStats(position) if getFantasyData
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
			@allplayers[position][playername]['projectedPointsFFNPPR'] = player.search('ppr').text
			@allplayers[position][playername]['projectedPointsFFNPPRLow'] = player.search('pprLow').text
			@allplayers[position][playername]['projectedPointsFFNPPRHigh'] = player.search('pprHigh').text
		end
	end

	def getFantasyDataStats(position)
		uri = URI(@fanstasydataurls[position])
		res = Net::HTTP.get_response(uri)
		html_doc  = Nokogiri::HTML res.body
		table = html_doc.css('#StatsGrid')
		c = 0

		table.css('tr').each do |tr|
			if c > 0
				playername = tr.css('td')[1].text
				@allplayers[position][playername] = {} if @allplayers[position][playername].nil?
				@allplayers[position][playername]['team'] = tr.css('td')[4].text
				@allplayers[position][playername]['projectedPointsFantasyData'] = tr.css('td').last.text
			end
			c+=1
		end
	end
end

options = {}
optparse = OptionParser.new do |opts|
	opts.banner = "Usage: football.rb [options]"

	opts.on('-p', '--position NAME', 'Position (can only be QB, RB, or WR)') { |v| options[:position] = v }
	opts.on('-c', '--csv BOOL', 'Print to CSV') { |v| options[:print] = v }
end.parse!

timestamp = Time.new
time = timestamp.strftime("%Y%m%d")

config = YAML.load_file('config.yaml') # loading config info for database

football = FootballProjections.new(config['fantasyFootballNerd']['apiKey'])
football.getStats(options[:position])
allplayers = football.instance_variable_get(:@allplayers)

if options[:print]
	File.open("../tmp/#{options[:position]}.json", "w") do |file|
		file.write(allplayers.to_json)
	end
end