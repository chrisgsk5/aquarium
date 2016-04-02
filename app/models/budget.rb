class Budget < ActiveRecord::Base

  has_many :tasks
  has_many :user_budget_associations

  attr_accessible :contact, :name, :overhead, :description, :email, :phone

  validates :name,  presence: true
  validates :email,  presence: true
  validates :phone,  presence: true
  validates :contact,  presence: true  
  validates :description,  presence: true  

  # validates_numericality_of :overhead, :greater_than_or_equal_to => 0.0, :less_than => 1.0 

  def spent_this_month user_id
    start = Date.today.beginning_of_month
    rows = Account.where("created_at >= ? AND budget_id = ? AND user_id = ?", start, id, user_id)
    amounts = rows.collect { |row| 
      row.transaction_type == "credit" ? -row.amount : row.amount
    }
    amounts.inject(0) { |sum,x| sum+x }    
  end

end