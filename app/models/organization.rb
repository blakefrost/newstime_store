class Organization
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String

  has_many :users
  has_many :editions
  has_many :publications

end
