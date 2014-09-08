# == Schema Information
#
# Table name: tags
#
#  id          :integer          not null, primary key
#  name        :string(255)
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :articles

  validates :name, :presence => true
end
