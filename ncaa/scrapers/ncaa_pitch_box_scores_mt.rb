#!/usr/bin/env ruby

require 'csv'

require 'nokogiri'
require 'open-uri'

#print "\n\nstarting pitching box scores...\n\n"

year = 2015
division = 3

  if year == 2012
	cat_id = 10083
  elsif year == 2013
	cat_id = 10121
  elsif year == 2014
	cat_id = 10461
  elsif year = 2015
	cat_id = 10781
  end

#require 'awesome_print'

class String
  def to_nil
    self.empty? ? nil : self
  end
end

base_url = 'http://stats.ncaa.org'
#base_url = 'http://anonymouse.org/cgi-bin/anon-www.cgi/stats.ncaa.org'

box_scores_xpath = '//*[@id="contentArea"]/table[position()>4]/tr[position()>2]'

#'//*[@id="contentArea"]/table[5]/tbody/tr[1]/td'

#periods_xpath = '//table[position()=1 and @class="mytable"]/tr[position()>1]'

nthreads = 10

base_sleep = 0
sleep_increment = 3
retries = 4

ncaa_team_schedules = CSV.open("csv/ncaa_team_schedules_#{year}_D#{division}.csv","r",{:col_sep => "\t", :headers => TRUE})
CSV.open("csv/ncaa_pitch_box_scores_#{year}_D#{division}.csv","w",{:col_sep => "\t"}) do |ncaa_box_scores|

#print "files opened!\n"
# Headers

ncaa_box_scores << ["game_id","section_id","player_id","player_name","player_url","position","App","GS","IP","H","R","ER","BB","SO","SHO","BF","OppAB","2B","3B","HR","WP","Balk","HBP","IBB","IR","IR-S","SH","SF","Pitches","GO","FO","W","L","SV","Order","KC"]

#print "headers added\n"

# Get game IDs

game_ids = []
ncaa_team_schedules.each do |game|
  game_ids << game["game_id"]
end

#print "get game IDs\n"

# Pull each game only once
# Modify in-place, so don't chain

game_ids.compact!
game_ids.sort!
game_ids.uniq!

#game_ids = game_ids[0..199]

#print "modified in place\n"

n = game_ids.size

gpt = (n.to_f/nthreads.to_f).ceil

threads = []

game_ids.each_slice(gpt).with_index do |ids,i|

  threads << Thread.new(ids) do |t_ids|

    found = 0
    n_t = t_ids.size

    t_ids.each_with_index do |game_id,j|

      sleep_time = base_sleep

#      game_url = 'http://stats.ncaa.org/game/play_by_play/%d' % [game_id]
#      game_url = 'http://anonymouse.org/cgi-bin/anon-www.cgi/http://stats.ncaa.org/game/box_score/#{game_id}?year_stat_category_id=#{cat_id}'
#	  game_url = "http://anonymouse.org/cgi-bin/anon-www.cgi/http://stats.ncaa.org/game/box_score/#{game_id}?year_stat_category_id=#{cat_id}"
	  game_url = "http://stats.ncaa.org/game/box_score/#{game_id}?year_stat_category_id=#{cat_id}"

#      print "Thread #{game_id}, category #{cat_id}, url #{game_url} ... \n"
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

      page.xpath(box_scores_xpath).each do |row|

        table = row.parent
        section_id = table.parent.xpath('table[position()>1 and @class="mytable"]').index(table)

        player_id = nil
        player_name = nil
        player_url = nil

        field_values = []
        row.xpath('td').each_with_index do |element,k|
          case k
          when 0 	# player name
            player_name = element.text.strip rescue nil
            link = element.search("a").first

            if not(link.nil?)
              link_url = link.attributes["href"].text
              player_url = link_url.split("cgi/")[1]
              parameters = link_url.split("/")[-1]
              player_id = parameters.split("=")[2]
            end
		  when 1	# position
			field_values += [element.text.strip]
          else		# all others (numbers)
            field_values += [element.text.strip.to_i]
          end
        end

        ncaa_box_scores << [game_id,section_id,player_id,player_name,player_url]+field_values

#		print " :) \n"
      end

    end

  end

end

threads.each(&:join)

#parts.flatten(1).each { |row| ncaa_play_by_play << row }

#print "\n\nfinished pitching box scores!\n\n"

#ncaa_box_scores.close

end
