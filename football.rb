require 'net/http'
require 'nokogiri'
require 'json'

class FootballProjections
	def initialize
		@allplayers = {}
		fantasyfootballnerdkey = "rbiqguw72u7j"
		@fantasyfootballnerdurls = {
			"QB" => "http://www.fantasyfootballnerd.com/service/weekly-rankings/xml/#{fantasyfootballnerdkey}/QB",
			"WR" => "http://www.fantasyfootballnerd.com/service/weekly-rankings/xml/#{fantasyfootballnerdkey}/WR",
			"RB" => "http://www.fantasyfootballnerd.com/service/weekly-rankings/xml/#{fantasyfootballnerdkey}/RB",
		}

		@nflurls = {
			'QB' => "http://api.fantasy.nfl.com/v1/players/scoringleaders?position=QB&sort=projectedPts",
			'RB' => "http://api.fantasy.nfl.com/v1/players/scoringleaders?position=RB&sort=projectedPts",
			'WR' => "http://api.fantasy.nfl.com/v1/players/scoringleaders?position=WR&sort=projectedPts",
		}
	end

	def getStats(position, getNFL = 1, getFFN = 1, getYahoo = 1)
		@allplayers[position] = {}
		
		getNFLStats(position) if getNFL
		getFantasyFootballNerdStats(position) if getFFN
		getYahooStats(position) if getYahoo
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

			if @allplayers[position][playername].nil?
				@allplayers[position][playername] = {}
			end
			
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

			if @allplayers[position][playername].nil?
				@allplayers[position][playername] = {}
			end
			
			@allplayers[position][playername]['team'] = player.search('team').text
			@allplayers[position][playername]['projectedPointsFFNStandard'] = player.search('standard').text
			@allplayers[position][playername]['projectedPointsFFNStandardLow'] = player.search('standardLow').text
			@allplayers[position][playername]['projectedPointsFFNStandardHigh'] = player.search('standardHigh').text
			@allplayers[position][playername]['projectedPointsFFNPPR'] = player.search('ppr').text
			@allplayers[position][playername]['projectedPointsFFNPPRLow'] = player.search('pprLow').text
			@allplayers[position][playername]['projectedPointsFFNPPRHigh'] = player.search('pprHigh').text
		end
	end

	def getYahooStats(position)
		
	end
end

football = FootballProjections.new

['QB', 'WR', 'RB'].each do |position|
	football.getStats(position)
end
print football.instance_variable_get(:@allplayers).to_json