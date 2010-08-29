module NIDAG
  
  # Simple class to represent the contents of an HTML table.
  # Basically just a grid with array accessor methods.
  # Uses R-style indexing.
  class DataGrid
  
    attr_accessor :data, :nnrow, :ncol, :vector
  
    def initialize(nrows, ncols)
      @data = Array.new(nrows)
      @data.map! { |c| Array.new(ncols, nil) }
      @nrow, @ncols = nrows, ncols
    end
  
    def [](r,c)
      @data[r][c]
    end
  
    def []=(r, c, val)
      @data[r][c] = val
      self
    end
  
    def to_a
      @data
    end
  
    def nrow
      @data.size
    end
  
    def ncol
      @data[0].size
    end
  
    # Find next open position and add value(s) to grid.
    def add_val(val, rows=1, cols=1)
      # Scan for next open position
      open = @data.flatten.index(nil)
      # Create extra rows if nothing is open. Assumes that there will never
      # be a problem with column counts--i.e., that HTML tables will always be
      # valid. But this could break with badly formatted HTML.
      if open.nil?
        open = @data.size * @ncols
        rows.times { |i| @data << Array.new(@ncols, nil) } 
      end
      # Update
      ri = open / @ncols
      ci = open % @ncols
      rows.times { |r|
        cols.times { |c|
          content = if cols > 1
            c == 0 ? "@@#{val}@#{cols}" : "@@#{val}"
          else
            val
          end
          self[ri+r, ci+c] = content
        }
      }
    end
  end
  
end