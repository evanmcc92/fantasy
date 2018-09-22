require 'net/http'
require 'nokogiri'

class FootballProjections
	def initialize(fantasyfootballnerdkey)
		timestamp = Time.new
		time = timestamp.strftime("%Y-%m-%d %H:%M:%S (%Z)")
		@allplayers = {
			metadata: {
				created_at: time,
				week: nil
			},
			playerData: {}
		}

		@positions = ['QB', 'RB', 'WR', 'TE', 'DEF', 'K']
		@fantasyfootballnerdkey = fantasyfootballnerdkey ? fantasyfootballnerdkey : nil
	end

	def getStats(getNFL = 1, getFFN = 1)
		@positions.each do |p|
			@allplayers[:playerData][p] = {}

			getNFLStats(p) if getNFL
			getFantasyFootballNerdStats(p) if getFFN && @fantasyfootballnerdkey
			getAverage(p) if getNFL && getFFN
		end	

		return @allplayers	
	end
	
	def getNFLStats(position)
		uri = URI("http://api.fantasy.nfl.com/v1/players/scoringleaders?position=#{position}&sort=projectedPts")
		res = Net::HTTP.get_response(uri)
		xml_doc  = Nokogiri::Slop res.body
		scoringLeaders = xml_doc.scoringLeaders
		@allplayers[:metadata][:week] = scoringLeaders.attr("week") if @allplayers[:metadata][:week].nil?

		players = scoringLeaders.scoringLeader.players
		players.player.each do |p|
			playerFName = p.attr("firstName")
			playerLName = p.attr("lastName")
			playername = "#{playerFName} #{playerLName}"

			@allplayers[:playerData][position][playername] = {} if @allplayers[:playerData][position][playername].nil?
			
			@allplayers[:playerData][position][playername] = {}
			@allplayers[:playerData][position][playername]['team'] = p.attr("teamAbbr")
			@allplayers[:playerData][position][playername]['vs'] = p.attr("opponentTeamAbbr")
			@allplayers[:playerData][position][playername]['gameTime'] = p.attr("status")
			@allplayers[:playerData][position][playername]['projectedPointsNFL'] = p.attr("projectedPts").to_f
		end
	end

	def getFantasyFootballNerdStats(position)
		uri = URI("https://www.fantasyfootballnerd.com/service/weekly-rankings/xml/#{@fantasyfootballnerdkey}/#{position}")
		res = Net::HTTP.get_response(uri)
		xml_doc  = Nokogiri::Slop res.body
		players = xml_doc.WeeklyRankings.Rankings
		players.Player.each do |player|
			playername = player.search('name').text
			playername = playername.gsub(/Jr\.||Sr\.||III/, '').strip

			@allplayers[:playerData][position][playername] = {} if @allplayers[:playerData][position][playername].nil?
			
			@allplayers[:playerData][position][playername]['team'] = player.search('team').text
			@allplayers[:playerData][position][playername]['projectedPointsFFNStandard'] = player.search('standard').text.to_f
			@allplayers[:playerData][position][playername]['projectedPointsFFNStandardLow'] = player.search('standardLow').text.to_f
			@allplayers[:playerData][position][playername]['projectedPointsFFNStandardHigh'] = player.search('standardHigh').text.to_f
			@allplayers[:playerData][position][playername]['weightedPointsFFNStandard'] = ((player.search('standardHigh').text.to_f + player.search('standardLow').text.to_f + player.search('standardHigh').text.to_f)/3).round(2)
			@allplayers[:playerData][position][playername]['injury'] = player.search('injury').text
			@allplayers[:playerData][position][playername]['practiceStatus'] = player.search('practiceStatus').text
			@allplayers[:playerData][position][playername]['gameStatus'] = player.search('gameStatus').text
		end
	end

	def getAverage(position)
		players = @allplayers[:playerData][position]
		players.each do |player|
			playername = player.first
			playerObj = @allplayers[:playerData][position][playername]
			arr = []
			if playerObj['projectedPointsNFL']
				arr.push(playerObj['projectedPointsNFL'])
			end
			if playerObj['weightedPointsFFNStandard']
				arr.push(playerObj['weightedPointsFFNStandard'])
			end
			@allplayers[:playerData][position][playername]['average'] = arr.inject{ |sum, el| sum + el }.to_f / arr.size
		end
	end

	public :initialize, :getStats
	private :getNFLStats, :getFantasyFootballNerdStats, :getAverage
end
