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

# http://rubular.com/r/8OPeHxco0l
VERTICAL_LINE_REGEX=/^\s*(.+?)\:\s(.+)$/

def in_vertical_format?(input)
  logger.info 'in_vertical_format?'
  # in the first four lines you should encounter a line that has the format
  input.split("\n")[0,4].detect do |line|
    line =~ VERTICAL_LINE_REGEX
  end
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

# ---------------------------------------------------------------------------
def process_vertical_format(table_name, input)
  columns = []
  queries = []
  values  = []

  input.split("\n").each do |line|
    if line.match(/^\*+/) # start of a new "row"
      queries << create_vertical_query(table_name, columns, values)

      # reset everything for the next "row"
      columns = []
      values  = []
    else
      if match = line.match(VERTICAL_LINE_REGEX)
        columns << match.captures[0].strip
        values  << match.captures[1].strip
      elsif match = line.match(/^\d+\srow in set \([\d\.]+ sec\)/)
        # http://rubular.com/r/Ua5bIRDhBj
        # this is the end of the query, ignore this line
      else
        # if we are here, this "may" be part of a value with newlines in it?
        if !values.last.nil? # is there anything in the last value?
          values[-1] = values[-1] + "\n" + line
        end
      end
    end
  end

  # see if we have anything left to work on
  queries << create_vertical_query(table_name, columns, values)

  queries.compact
end

def create_vertical_query(table_name, columns=[], values=[])
  return nil if columns.empty? && values.empty?

  if columns.count != values.count
    raise 'Column and value counts do not match'
  end
  generate_insert_query(table_name, columns, values)
end

# ---------------------------------------------------------------------------
def process_standard_format(table_name, input)
  columns, value_rows = find_columns_and_value_rows_standard(input)

  if columns.empty? || value_rows.empty?
    raise 'Invalid input received, try again.'
  end
  # make sure we have the same number of columns and values
  if columns.count != value_rows.first.count
    raise 'Column and value counts do not match.'
  end

  # returns the set of queries
  value_rows.collect { |row| generate_insert_query(table_name, columns, row) }
end

def find_columns_and_value_rows_standard(input)
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
