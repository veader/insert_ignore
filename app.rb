#!/usr/bin/env ruby

require 'sinatra'

get '/' do
  erb :index
end

post '/' do
  @output = \
    begin
      generate_insert_query(params[:table_name], params[:select_result])
    rescue Exception => ex
      ex.message
    end

  erb :results
end


# ---------------------------------------------------------------------------
def generate_insert_query(table_name, input)
  columns = []
  values  = []

  # look through input for our columns and values
  input.split("\n").each do |line|
    next if line =~ /^\+\-/ # skip border rows
    next if line !~ /^\|/   # skip anything that doesn't begin with "|"

    row = line.split('|').map { |v| v.strip }
    row.shift if row.first == ''
    row.pop if row.last == ''
    if row.first == 'id'
      columns = row
    else
      values  = row
    end
  end

  raise 'Invalid input received, try again.' if columns.empty? || values.empty?
  # make sure we have the same number of columns and values
  raise 'Column and value counts do not match.' if columns.count != values.count

  columns_str = columns.join(', ')
  values_str = \
    values.collect { |v| needs_quotes?(v) ? "\"#{v}\"" : v }.join(', ')
  "INSERT IGNORE INTO #{table_name} (#{columns_str}) VALUES (#{values_str})"
end

def needs_quotes?(value)
  # we don't need to quote if we are NULL or a number
  !(value.upcase == 'NULL' || value =~ /^[\d\.]*$/)
end
