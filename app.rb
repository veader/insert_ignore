#!/usr/bin/env ruby

require 'sinatra'

get '/' do
  erb :index
end

post '/' do
  @output = \
    begin
      generate_sql(params[:table_name], params[:select_result])
    rescue Exception => ex
      ex.message
    end.gsub(/\n/, '<br><br>')

  erb :results
end


# ---------------------------------------------------------------------------
def generate_sql(table_name, input)

  columns, value_rows = find_columns_and_value_rows(input)

  raise 'Invalid input received, try again.' if columns.empty? || value_rows.empty?
  # make sure we have the same number of columns and values
  raise 'Column and value counts do not match.' if columns.count != value_rows.first.count

  queries = \
  value_rows.collect { |row| generate_insert_query(table_name, columns, row) }

  queries.join("\n")
end

def find_columns_and_value_rows(input)
  columns    = []
  value_rows = []

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
      value_rows << row
    end
  end

  [columns, value_rows]
end

def generate_insert_query(table, columns, values)
  columns_str = columns.join(', ')
  values_str = \
    values.collect { |v| needs_quotes?(v) ? "\"#{v}\"" : v }.join(', ')
  "INSERT IGNORE INTO #{table} (#{columns_str}) VALUES (#{values_str});"
end

def needs_quotes?(value)
  # we don't need to quote if we are NULL or a number
  !(value.upcase == 'NULL' || value =~ /^[\d\.]*$/)
end
