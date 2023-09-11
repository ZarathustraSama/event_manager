# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  digits = phone_number.gsub(/\D/, '').split('')
  digits.shift if digits.length == 11 && digits[0] == 1
  return "(#{digits[0..2].join('')})-#{digits[3..5].join('')}-#{digits[6..9].join('')}" if digits.length == 10

  nil
end

def add_reg_date(reg_hours, reg_days, reg_date)
  rd = Time.strptime(reg_date, '%m/%d/%y %H:%M')
  add_data(reg_hours, rd.hour)
  add_data(reg_days, rd.strftime('%A'))
end

def add_data(reg_data, data)
  if reg_data[data]
    reg_data[data] += 1
  else
    reg_data[data] = 1
  end
end

def select_top_reg_data(reg_data)
  top_data = []
  reg_data.group_by { |_key, value| value }.max_by { |key, _value| key }[1].each { |data| top_data << data[0] }
  top_data
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip, levels: 'country', roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue Google::Apis::ClientError
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

puts 'Event Manager Initialized.'

contents = CSV.open(
  '../event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('../form_letter.erb')
erb_template = ERB.new template_letter

reg_hours = {}
reg_days = {}

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phone_number = clean_phone_number(row[:homephone])

  add_reg_date(reg_hours, reg_days, row[:regdate])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

puts 'Event Manager Terminated.'
puts "Peak registration hour(s): #{select_top_reg_data(reg_hours).join(', ')}"
puts "Peak registration day(s): #{select_top_reg_data(reg_days).join(', ')}"
