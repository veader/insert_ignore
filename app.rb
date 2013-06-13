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

VERTICAL_LINE_REGEX=/^\s+(.+?)\:\s(.+)$/

# ---------------------------------------------------------------------------
def generate_sql(table_name, input)
  queries = process_input(table_name, input)
  queries.join("\n")
end

def process_input(table_name, input)
  if in_vertical_format?(input)
    process_vertical_format(table_name, input)
  else
    process_standard_format(table_name, input)
  end
end

def in_vertical_format?(input)
  logger.info 'in_vertical_format?'
  # in the first four lines you should encounter a line that has the format
  # http://rubular.com/r/Pg5eIwsMZ9
  input.split("\n")[0,4].detect do |line|
    line =~ VERTICAL_LINE_REGEX
  end
end

def process_vertical_format(table_name, input)
  ["That's in \\G format. We are working on support for it." +
   "Until then try standard select format output."]
end

def process_standard_format(table_name, input)
  columns, value_rows = find_columns_and_value_rows(input)

  raise 'Invalid input received, try again.' if columns.empty? || value_rows.empty?
  # make sure we have the same number of columns and values
  raise 'Column and value counts do not match.' if columns.count != value_rows.first.count

  value_rows.collect { |row| generate_insert_query(table_name, columns, row) }
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
  # http://rubular.com/r/G7VjKIwHdD - make sure this doesn't capture IPs
  !(value.upcase == 'NULL' || value =~ /^\d+\.?\d*$/)
end
