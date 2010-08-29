module NIDAG
  
  class Tag < ActiveRecord::Base
    
    belongs_to :article
    belongs_to :term
    accepts_nested_attributes_for :term
    
  end
 
end