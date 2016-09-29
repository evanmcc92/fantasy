require 'net/http'
require 'nokogiri'
require 'json'
require 'csv'

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

		@fanstasydataurls = {
			'QB' => 'https://fantasydata.com/nfl-stats/fantasy-football-weekly-projections.aspx?fs=0&stype=0&sn=0&scope=1&w=3&ew=3&s=&t=0&p=1&st=FantasyPoints&d=1&ls=&live=false&pid=false&minsnaps=4',
			'RB' => 'https://fantasydata.com/nfl-stats/fantasy-football-weekly-projections.aspx?fs=0&stype=0&sn=0&scope=1&w=3&ew=3&s=&t=0&p=2&st=FantasyPoints&d=1&ls=&live=false&pid=false&minsnaps=4',
			'WR' => 'https://fantasydata.com/nfl-stats/fantasy-football-weekly-projections.aspx?fs=0&stype=0&sn=0&scope=1&w=3&ew=3&s=&t=0&p=3&st=FantasyPoints&d=1&ls=&live=false&pid=false&minsnaps=4',
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
				@allplayers[position][playername]['projectedPointsFantasyData'] = tr.css('td').last.text
			end
			c+=1
		end
	end
end

timestamp = Time.new
time = timestamp.strftime("%Y%m%d")

football = FootballProjections.new

['QB', 'WR', 'RB'].each do |position|
	football.getStats(position)
end

allplayers = football.instance_variable_get(:@allplayers)

allplayers.each do |position, players|
	CSV.open("#{position}-#{time}.csv", "w") do |csv|
		csv << ['Name', 'Team', 'Projected Points NFL','Projected Points FFN Standard','Projected Points FFN StandardLow','Projected Points FFN StandardHigh','Projected Points FFN PPR','Projected Points FFN PPRLow','Projected Points FFN PPRHigh', 'Projected Points Fantasy Data']
		players.each do |name, stats|
			csv << [name,stats['team'],stats['projectedPointsNFL'],stats['projectedPointsFFNStandard'],stats['projectedPointsFFNStandardLow'],stats['projectedPointsFFNStandardHigh'],stats['projectedPointsFFNPPR'],stats['projectedPointsFFNPPRLow'],stats['projectedPointsFFNPPRHigh'],stats['projectedPointsFantasyData']]
		end
	end
end