# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def format_phone(phone)
  one, two, three = phone.match(/(\d\d\d).*(\d\d\d).*(\d\d\d\d)/).captures
  "#{one}-#{two}-#{three}"
end

# If the phone number is less than 10 digits, assume that it is a bad number
# If the phone number is 10 digits, assume that it is good
# If the phone number is 11 digits and the first number is 1, trim the 1 and use the remaining 10 digits
# If the phone number is 11 digits and the first number is not 1, then it is a bad number
# If the phone number is more than 11 digits, assume that it is a bad number
def clean_phone(phone)
  phone = phone.scan(/\d/).join('')
  if phone.length == 11 && phone[0] == '1'
    format_phone(phone[1..10])
  elsif phone.length < 10 || phone.length >= 11
    'Bad Number'
  else
    format_phone(phone)
  end
end

def clean_date(time, hours, days)
  # clean date
  date, hour = time.split(' ')
  date = date.split('/').map { |d| d.rjust(2, '0') }.join('/')
  hour = hour.split(':').map { |h| h.rjust(2, '0') }.join(':')
  # get Time object
  new_date = Time.strptime("#{date} #{hour}", '%m/%d/%y %H:%M')
  # retrieve hour and days and store hours in array
  hours << new_date.hour
  days << new_date.to_date.wday
  new_date
end

def time_targeting(time)
  # count hours/days and store in hash
  hour_count =
    time.reduce(Hash.new(0)) do |count, value|
      count[value] += 1
      count
    end
  sorted_count = hour_count.sort_by { |_, count| count }
  sorted_count.reverse!
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

hours = []
days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  time = row[:regdate]

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  phone = clean_phone(row[:homephone])
  puts phone

  puts clean_date(time, hours, days)
end

# display hash
time_targeting(hours).each do |row|
  puts "#{row[1]} people registered at #{row[0]}h"
end

time_targeting(days).each do |row|
  puts "#{row[1]} people registered on #{Date::DAYNAMES[row[0]]}"
end
