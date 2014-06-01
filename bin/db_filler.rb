#!/usr/bin/env ruby -wU

$LOAD_PATH << './lib'

require "earningfocus_db_filler"
require "sec_statement_parser"
require "awesome_print"


SYMBOL_LIST = "#{Dir.home}/.sec_statement_parser/data/nasdaq_traded_stock_list.txt"
PROJECT_ROOT_DIR = File.expand_path('../../', __FILE__)
PARSE_ERROR_FILE = "#{PROJECT_ROOT_DIR}/tmp/parse_error.txt"
LINK_ERROR_FILE = "#{PROJECT_ROOT_DIR}/tmp/link_error.txt"
SAVE_TO_DATABASE_FAIL_FILE = "#{PROJECT_ROOT_DIR}/tmp/save_to_database_error.txt"
UNKNOWN_ERROR_FILE = "#{PROJECT_ROOT_DIR}/tmp/unknown_error.txt"
LAST_PARSED_SYMBOL_FILE = "#{PROJECT_ROOT_DIR}/tmp/last_parsed_symbol.txt"

def push_symbol_to_file(symbol, path)
  begin
    array = IO.readlines(path).map(&:chomp)
  rescue
    array = []
  end
  array << symbol unless array.include? symbol
  array.sort!
  File.open(path, 'w') do |f|
    f.puts(array)
  end
end

def remove_symbol_from_file(symbol, path)
  begin
    array = IO.readlines(path).map(&:chomp)
  rescue
    array = []
  end
  array.delete(symbol) if array.include?(symbol)
  File.open(path, 'w') do |f|
    f.puts(array)
  end
end


# Initialization
$interrupted = false
trap("SIGINT") { $interrupted = true }
begin
  File.open(LAST_PARSED_SYMBOL_FILE,'r') do |f|
    $last_parsed_symbol = f.readline.chomp
  end
rescue
  $last_parsed_symbol = 'A'
end

symbol_list = []
File.open(SYMBOL_LIST, 'r') do |f|
  f.each_line do |line|
    symbol_list << line.split('|')[0]
  end
  symbol_list.sort!
end

# symbol_list = %w(aapl)

symbol_list.each do |symbol|

  break if $interrupted
  next if symbol < $last_parsed_symbol

  symbol.upcase!
  parser = SecStatementParser::Statement.new(symbol)

  # get list
  tries = 1
  begin
    parser.get_list
  rescue
    if tries < 10
      tries += 1
      retry
    else
      push_symbol_to_file(symbol, LINK_ERROR_FILE)
      next
    end
  end
  remove_symbol_from_file(symbol, LINK_ERROR_FILE)

  # parse
  tries = 1
  begin
    parser.parse_url_list
  rescue ParseError => e
    puts e.message
    puts e.backtrace.inspect
    push_symbol_to_file(symbol, PARSE_ERROR_FILE)
    next
  rescue
    if tries < 10
      tries += 1
      retry
    else
      push_symbol_to_file(symbol, UNKNOWN_ERROR_FILE)
      next
    end
  end

  puts "Parse #{symbol} success, prepare to fill into database"

  parser.statements.each do |pst|
    stock = Stock.find_by_symbol(symbol); stock = Stock.new if stock.nil?

    # Update stock info if it is outdated
    if stock.fiscal_period_end_date_of_doc_that_stock_info_parsed_from.nil? or
      stock.fiscal_period_end_date_of_doc_that_stock_info_parsed_from < Date.parse(pst[:fiscal_period_end_date])

      stock.fiscal_period_end_date_of_doc_that_stock_info_parsed_from = pst[:fiscal_period_end_date]
      stock.symbol       = symbol
      stock.country      = 'US'
      stock.company_name = pst[:registrant_name]
      stock.cik          = pst[:cik]

      stock.save
    end

    st = Statement.find_by(symbol:                  symbol,
                           document_type:           pst[:document_type],
                           fiscal_period_end_date:  pst[:fiscal_period_end_date])


    st = Statement.new if st.nil?

    # basic info
    st.symbol                 = symbol
    st.stock_id               = stock.id
    st.document_type          = pst[:document_type]
    st.year                   = pst[:year]
    st.quarter                = pst[:fiscal_period] =~ /^Q[1-4]{1}$/ ? pst[:fiscal_period][1] : nil
    st.fiscal_period_end_date = Date.parse(pst[:fiscal_period_end_date])
    st.statement_link         = pst[:statement_link]

    case pst[:document_type]
    when '10-K', '10-K/A'
      st.fiscal_period_duration_in_month = 12
      period_duration_sym = :last_12month_data
    when '10-Q', '10-Q/A'
      st.fiscal_period_duration_in_month = 3
      period_duration_sym = :last_3month_data
    else
      raise "wrong document_type"
    end

    # ap pst[period_duration_sym] # debug

    # data
    st.revenue                    = pst[period_duration_sym][:revenue]
    st.gross_profit               = pst[period_duration_sym][:gross_profit]
    st.operating_income           = pst[period_duration_sym][:operating_income]
    st.net_income_before_tax      = pst[period_duration_sym][:net_income_before_tax]
    st.net_income_after_tax       = pst[period_duration_sym][:net_income_after_tax]
    st.cost_of_revenue            = pst[period_duration_sym][:cost_of_revenue]
    st.total_operating_expense    = pst[period_duration_sym][:total_operating_expense]
    st.eps_basic                  = pst[period_duration_sym][:eps_basic]
    st.eps_diluted                = pst[period_duration_sym][:eps_diluted]

    # calculate nil columns
    st.gross_profit = st.revenue - st.cost_of_revenue if st.gross_profit.nil? and !st.revenue.nil? and !st.cost_of_revenue.nil?
    st.cost_of_revenue = st.revenue - st.gross_profit if st.cost_of_revenue.nil? and !st.revenue.nil? and !st.gross_profit.nil?

    st.operating_income = st.revenue - st.total_operating_expense if st.operating_income.nil? and !st.revenue.nil? and !st.total_operating_expense.nil?
    st.total_operating_expense = st.revenue - st.operating_income if st.total_operating_expense.nil? and !st.revenue.nil? and !st.operating_income.nil?

    print "Saving #{st.statement_link.split('/').last} to database..."

    begin
      st.save!
      puts "ok".green
      if symbol > $last_parsed_symbol
        $last_parsed_symbol = symbol
        File.open(LAST_PARSED_SYMBOL_FILE, 'w') { |f| f.write($last_parsed_symbol) }
      end
    rescue
      puts "failed".red
      puts st.errors
      puts st.errors.messages
      ap pst
      ap st
      push_symbol_to_file(symbol, SAVE_TO_DATABASE_FAIL_FILE)
    end
  end
end
