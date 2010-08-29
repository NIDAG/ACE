module NIDAG

  ### REPRESENTS A SINGLE TABLE IN AN ARTICLE
  class Table < ActiveRecord::Base
  
    belongs_to :article
    has_many :peaks
  
    # Call when Table is finalized to number peaks serially
    def number_peaks
      num = 0
      self.peaks = peaks.map! { |p| p.number = (num += 1); p }
    end
  
    # Finalize before output. Currently just calls number_peaks.
    def finalize
      number_peaks
    end
    
  end
  
end