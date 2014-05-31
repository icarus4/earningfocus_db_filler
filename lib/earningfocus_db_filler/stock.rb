class Stock < ActiveRecord::Base
  has_many :statements, dependent: :destroy

  # save symbol as up case
  before_save { self.symbol = symbol.upcase }

  # symbol
  validates :symbol, presence: true, length: { within: 1..6 },
    uniqueness: { scope: :stock_exchange, case_sensitive: false }

  # company name
  validates :company_name, presence: true, length: { within: 1..128 }

  # country
  validates :country, presence: true

  # cik
  validates :cik, presence: true, length: { is: 10 }

  # stock exchange
  validates :stock_exchange, inclusion: { in: ['NYSE', 'NASDAQ', 'AMEX', 'NYSE Arca', 'OTCBB', nil] }

  # fiscal_period_end_date_of_doc_that_stock_info_parsed_from_cannot_be_in_the_future
  validate :fiscal_period_end_date_of_doc_that_stock_info_parsed_from_cannot_be_in_the_future


  def fiscal_period_end_date_of_doc_that_stock_info_parsed_from_cannot_be_in_the_future
    errors.add(:fiscal_period_end_date_of_doc_that_stock_info_parsed_from, "can't be in the future") if
      !fiscal_period_end_date_of_doc_that_stock_info_parsed_from.blank? and
      fiscal_period_end_date_of_doc_that_stock_info_parsed_from > Date.today
  end
end
