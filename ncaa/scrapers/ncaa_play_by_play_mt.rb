#!/usr/bin/env ruby

require 'csv'

require 'nokogiri'
require 'open-uri'

year = 2015
division = 3

#require 'awesome_print'

class String
  def to_nil
    self.empty? ? nil : self
  end
end

events = []
#events = ["Leaves Game","Enters Game","Defensive Rebound","Commits Foul","made Free Throw","Assist","Turnover","missed Three Point Jumper","Offensive Rebound","missed Two Point Jumper","made Layup","missed Layup","Steal","made Two Point Jumper","made Three Point Jumper","missed Free Throw","Blocked Shot","Deadball Rebound","30 Second Timeout","Media Timeout","Team Timeout","made Dunk","20 Second Timeout","Timeout","made Tip In","missed Tip In","missed Dunk","made","missed","missed Deadball"]

#base_url = 'http://stats.ncaa.org'
base_url = 'http://anonymouse.org/cgi-bin/anon-www.cgi/stats.ncaa.org'

play_xpath = '//table[position()>1 and @class="mytable"]/tr[position()>1]'
innings_xpath = '//table[position()=1 and @class="mytable"]/tr[position()>1]'

nthreads = 10

base_sleep = 0
sleep_increment = 3
retries = 4

ncaa_team_schedules = CSV.open("csv/ncaa_team_schedules_#{year}_D#{division}.csv","r",{:col_sep => "\t", :headers => TRUE})
CSV.open("csv/ncaa_games_pbp_#{year}_D#{division}.xls","w",{:col_sep => "\t"}) do |ncaa_play_by_play|
CSV.open("csv/ncaa_innings_#{year}_D#{division}.xls","w",{:col_sep => "\t"}) do |ncaa_innings|

# Headers

#ncaa_play_by_play << ["game_id","inning_id","event_id","team_player","team_event","team_text","team_score","opponent_score","score","opponent_player","opponent_event","opponent_text"]
ncaa_play_by_play << ["game_id","inning_id","event_id","team_text","team_score","opponent_score","opponent_text"]

ncaa_innings << ["game_id", "is_home", "team_id", "team_name", "team_url", "inning_scores", "team_rhe"]

# Get game IDs

game_ids = []
ncaa_team_schedules.each do |game|
  game_ids << game["game_id"]
end

# Pull each game only once
# Modify in-place, so don't chain

game_ids.compact!
game_ids.sort!
game_ids.uniq!

#game_ids = game_ids[0..199]

n = game_ids.size

gpt = (n.to_f/nthreads.to_f).ceil

threads = []

game_ids.each_slice(gpt).with_index do |ids,i|

  threads << Thread.new(ids) do |t_ids|

    found = 0
    n_t = t_ids.size

    t_ids.each_with_index do |game_id,j|

      sleep_time = base_sleep

      game_url = 'http://stats.ncaa.org/game/play_by_play/%d' % [game_id]
      #game_url = 'http://anonymouse.org/cgi-bin/anon-www.cgi/http://stats.ncaa.org/game/play_by_play/%d' % [game_id]

#      print "Thread #{thread_id}, sleep #{sleep_time} ... "
#      sleep sleep_time

      tries = 0
      begin
        page = Nokogiri::HTML(open("#{game_url}",'User-Agent' => 'ruby'))
      rescue
        sleep_time += sleep_increment
#        print "sleep #{sleep_time} ... "
        sleep sleep_time
        tries += 1
        if (tries > retries)
          next
        else
          retry
        end
      end

      sleep_time = base_sleep

      found += 1

      print "#{i}, #{game_id} : #{j+1}/#{n_t}; found #{found}/#{n_t}\n"

      page.xpath(play_xpath).each_with_index do |row,event_id|

        table = row.parent
        inning_id = table.parent.xpath('table[position()>1 and @class="mytable"]').index(table)

#        time = row.at_xpath('td[1]').text.strip.to_nil rescue nil
        team_text = row.at_xpath('td[1]').text.strip.to_nil rescue nil
        score = row.at_xpath('td[2]').text.strip.to_nil rescue nil
        opponent_text = row.at_xpath('td[3]').text.strip.to_nil rescue nil

        team_event = nil
        if not(team_text.nil?)
          events.each do |e|
            if (team_text =~ /#{e}$/)
              team_event = e
              break
            end
          end
        end

        team_player = team_text.gsub(team_event,"").strip rescue nil

        opponent_event = nil
        if not(opponent_text.nil?)
          events.each do |e|
            if (opponent_text =~ /#{e}$/)
              opponent_event = e
              break
            end
          end
        end

        opponent_player = opponent_text.gsub(opponent_event,"").strip rescue nil

        scores = score.split('-') rescue nil
        team_score = scores[0].strip rescue nil
        opponent_score = scores[1].strip rescue nil

        ncaa_play_by_play << [game_id,inning_id,event_id,team_text,team_score,opponent_score,opponent_text]

      end

      page.xpath(innings_xpath).each_with_index do |row,section_id|
        team_inning_scores = []
#        section = [game_id,section_id]
        team_name = nil
        link_url = nil
        team_url = nil
        team_id = nil
        row.xpath('td').each_with_index do |element,i|
          case i
          when 0
            team_name = element.text.strip rescue nil
            link = element.search("a").first

            if not(link.nil?)
              link_url = link.attributes["href"].text
              team_url = link_url.split("cgi/")[1]
              parameters = link_url.split("/")[-1]
              team_id = parameters.split("=")[1]
            end
#            section += [team_id, team_name, team_url]
          else
            team_inning_scores += [element.text.strip.to_i]
          end
        end
		team_totals = team_inning_scores[-3, 3]
		team_inning_scores = team_inning_scores[0...-3]
        ncaa_innings << [game_id,section_id,team_id,team_name,team_url,team_inning_scores,team_totals]
      end
    end

  end

end

threads.each(&:join)

#parts.flatten(1).each { |row| ncaa_play_by_play << row }

end

#ncaa_play_by_play.close

end
