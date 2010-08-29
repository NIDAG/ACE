module NIDAG
  
  class Peak < ActiveRecord::Base 
    
    belongs_to :table
  
    def set_attr(key, val)
      self.send("#{key}=", val)
      self
    end
  
    def set_coords(x,y,z)
      self.x, self.y, self.z = x, y, z
      self
    end
    
    def add_col(key, val)
      self.columns[key] = val
      self
    end
  
    # Validates Peak. Considers peak invalid if:
    # * At least one of X, Y, Z is nil or missing
    # * Any |coordinate| > 100
    # * Two or more columns are zeroes (most of the time this
    #   will indicate a problem, but occasionally a real coordinate)
    # Depending on config, either excludes peak, or allows it through
    # but flags potential problems for later inspection.
    def validate!
      [x, y, z].each { |c| return false if c == '' or c.nil? }
      sorted = [x.abs, y.abs, z.abs].sort
      if EXTRA_VALIDATION
        if x.abs >= 100 or y.abs >= 100 or z.abs >= 100
          self.problems << "Invalid coordinate: at least one dimension >= 100."
        end
        if sorted[0] == 0 and sorted[1] == 0
          self.problems << "At least two dimensions have value == 0; coordinate may not be real."
        end
      elsif x.abs >= 100 or y.abs >= 100 or z.abs >= 100 or sorted[0] == 0 and sorted[1] == 0
        return false
      end
      self
    end
  
  end
  
end