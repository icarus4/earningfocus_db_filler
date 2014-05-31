class Statement < ActiveRecord::Base
  belongs_to :stock

  # stock id
  validates :stock_id, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # year
  validates :year, presence: true, length: { is: 4 },
    numericality: { greater_than_or_equal_to: 1900 }

  # quarter
  validates :quarter, length: { is: 1 }, allow_nil: true,
    numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 4 }

  # revenue
  validates :revenue, presence: { message: "revenue cannot not be blank" },
    numericality: { greater_than_or_equal_to: 0 }

  # gross_profit
  validates :gross_profit, allow_nil: true, numericality: { greater_than_or_equal_to: 0 }

  # symbol
  validates :symbol, presence: true, length: { within: 1..6 }

  # fiscal_period_end_date
  validates :symbol, presence: true

  # fiscal_period_duration_in_month
  validates :fiscal_period_duration_in_month, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # avoid duplicated report
  validates_uniqueness_of :quarter, :fiscal_period_end_date, scope: [:stock_id, :year]

end
