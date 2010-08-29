# encoding: UTF-8
module NIDAG
  
  ### Create a new Table from a standardized representation generated
  ### by a JournalParser.
  class TableParser
  
    # Takes standardized table representation as input and returns a Table object.
    # Input is a 3D array, where the first dimension indexes rows, the second
    # indexes columns within rows, and the third indexes cells within columns.
    # Cells are represented by a 2-element array, where the first element is the
    # value within the cell, and the second is the number of columns that cell spans
    # (i.e., this is the colspan value from the HTML table).
    def self.parse(data)
    
      # Create table
      table = Table.new
      
      # Find number of columns
      ncols = data.map { |r| r.size}.max
    
      # Identify column names: first occurrence of unique (i.e. colspan=1) label.
      # Also track multi-column labels for group names.
      labels = Array.new(ncols, nil)
      multi_labs = {}
      data.each_index { |i|
        r = data[i]
        r.each_index { |j|
          val = r[j]
          if val != '' and val !~ /^@@/ and labels[j].nil?
            # Need to handle first column separately, because first value in table
            # is often mistaken for label if label is left blank. In that case,
            # assume the first column denotes region.
            labels[j] =
            # If all other labels have been found, or if there are lots of numbers
            # in the row, we must already be in contents.
            # Note: known to fail in the presence of multiple unlabeled region columns.
            # See e.g., CerCor bhl081, table 2.
            if j == 0 and (labels[1,99].index(nil).nil? or r.join("/") =~ /\d+.*\d+.*\d+/)
              'region'
            else
              val
            end
          #elsif span > 1 and val != ""
          elsif val =~ /^@@(.*)@(\d+)$/
            #multi_labs["#{cid-span+1}/#{span}"] = val
            multi_labs["#{j}/#{$2}"] = $1
          end
        }
      }
    
      # Sometimes tables have bad information (i.e., incorrect colspan attribute; e.g.,
      # CerCor bhj050), so need to chomp invalid columns at the end.
      labels.compact!
      ncols = labels.size
    
      # Sometimes tables have a single "Coordinates" column name
      # despite breaking X/Y/Z up into 3 columns, so we account for this here.
      multi_labs.each { |k,v| 
        if v.downcase =~ /(ordinate|x.*y.*z)/
          st, span = k.split("/")
          if labels[st.to_i, span.to_i].join('') !~ /[a-zA-Z]/
            puts "Possible multi-column coordinates found: #{k}, #{v}" if VERBOSE
            labels[st.to_i, span.to_i] = %w[x y z]
          end
        end
      }
    
      # Some tables have a more complex format that can't be read properly.
      # For now, just skip any table that has nil column labels after parsing.
      return nil if !labels.index(nil).nil?
    
      # Try to recognize standard columns based on labels.
      # The biggest problem is distinguishing z-plane coordinates from z-scores.
      # Ultimately, this should rely on a case comparison across multiple cols.
      standard_cols = {}
      found_x = false  # used to speed up processing of z columns
      labels.each_index { |i|
        lab = labels[i].downcase
        s = 
        case lab
        when /region|anatom/
            'region'
        when /(^\s*ba$)|brodmann/
          'ba'
        when /sphere|(^\s*h$)|^\s*hem|^\s*side/
          'hemisphere'
        when /(^k$)|(mm.*?3)|volume|voxels|size|extent/
          'size'
        when /^\s*x\s*$/, /^\s*y\s*$/
          found_x = true if lab == 'x'
          lab
        when /^\s*z\s*$/
          # For z, we need to distinguish z plane from z-score.
          # Use simple heuristics:
          # * If no 'x' column exists, this must be a z-score
          # * If the preceding label was anything but 'y', must be a z-score
          # * Otherwise it's a z coordinate
          # Note: this could theoretically break if someone has non-contiguous
          # x-y-z columns, but this seems unlikely. If it does happen,
          # an alternative approach would be to check if the case of the 'z' column
          # matches the case of the 'x' column and make determination that way.
          if !found_x or labels[i-1].downcase != 'y'
            'statistic'
          else
            'z'
          end
        when /rdinate/
          # downcase =~ /(ordinate|x.*y.*z)/
        when 't', /^(z|t).*(score|value)/
          'statistic'
        when /p.*val/
          'p_value'
        else
          nil
        end
        standard_cols[i] = s if !s.nil?
      }
      
      # Uncomment the next line to filter coordinates more conservatively (not recommended)
      # return nil if standard_cols.size < 2

      # Identify groups: any set of columns where names repeat.
      # Find name of first repeating column, and all indices.
      repeats, rep_col = {}, nil
      labels.each { |l|
        if repeats.key?(l)
          rep_col = l
          break
        else
          repeats[l] = 1
        end
      }
      group_cols = []
      labels.each_index { |i| group_cols << i if labels[i] == rep_col }
      
      # Iterate through rows
      groups = nil
      peak_num = 0
      data.each { |r|
      
        next if r.size != ncols  # skip header rows
      
        # Skip row if any value matches the column label
        match_lab = false
        r.each_index { |i| match_lab = true if r[i] == labels[i] }
        next if match_lab
      
        # If row is empty except for value in first column, start new group.
        # Note that this won't extract a hierarchical structure;
        # e.g., if there are two consecutive group-denoting rows,
        # the second will overwrite the first.
        if r[0] != '' and r[1,99].join('') == ''
          groups = [r[0].strip]
          next
        end
      
        # Pass entire row...
        if group_cols.empty?
          peak = make_peak(r, labels, standard_cols, groups)
          table.peaks << peak.clone if peak.validate!
        # ...or iterate over groups. Need to select appropriate columns for each.
        else
          group_size = group_cols[1] - group_cols[0]  # ugly; fix later
          first_group_col = group_cols[0]
          last_group_col = group_cols[-1] + group_size
          group_cols.size.times { |j|
          
            # Get group name
            group_name = multi_labs["#{group_cols[j]}/#{group_size}"]
            groups = 
            if groups.nil?
              [group_name]
            else
              groups[1] = group_name
              groups
            end
          
            # Select columns
            cols = r[0,first_group_col] +
                   r[group_cols[j],group_size]
            cols += r[last_group_col,99] if last_group_col <= r.size
          
            # Create peak and add to table if it passes validation
            peak = make_peak(cols, labels, standard_cols, groups)
            table.peaks << peak if peak.validate!
          }
        end
      }
      table.finalize
      table
    end
  
    # Takes a set of columns and returns a new Peak object.
    private
    def self.make_peak(data, labels, standard_cols, groups)
    
      peak = Peak.new(:columns => {}, :problems => [])
      
      data.each_index { |i|
      
        # Format data type appropriately
        c = data[i]
        c = case c
        when /^[-\d]+$/ then c.to_i
        when /^[-\d\.]+$/ then c.to_f
        else c
        end
      
        # Set standard attributes if applicable and do validation where appropriate.
        # Generally, validation will not prevent a bad value from making it into the
        # Peak object, but it will flag any potential issues using the "problem" column.
        if standard_cols.key?(i)
          sc = standard_cols[i]
          case sc
          # Validate XYZ columns: Should only be integers (and possible trailing decimals).
          # If they're not, keep only leading numbers.
          when /^[xyz]$/
            if c.to_s !~ /^(-*\d+)\.*0*$/
              peak.problems << "Value in #{sc} column wasn't an integer"
              c = c.to_s[/^-*\d+/]
            end
          when 'region'
            peak.problems << "Value in region column is not a string" if c.to_s !~ /[a-zA-Z]/
          end
          peak.set_attr(standard_cols[i], c) 
        end
      
        # Always include all columns in record
        peak.add_col(labels[i], c)
      
        # Handle columns with multiple coordinates (e.g., 45;12;-12).
        # Assume that any series of 3 numbers in a non-standard column
        # reflects coordinates. Will fail if there are leading numbers!!!
        # Also need to remove space between minus sign and numbers; some ScienceDirect
        # journals leave a gap.
        if !standard_cols.key?(i) and c.to_s.strip =~ /([\p{Pd}\s]*\d{1,3})[,;\s]+([\p{Pd}\s]*\d{1,3})[,;\s]+([\p{Pd}\s]*\d{1,3})/u
          x,y,z = [$1, $2, $3].map { |val| val.gsub(/-\s+/, '-').to_i }
          if VERBOSE
            puts "Found multi-coordinate column: #{c}"
            puts "\t...and extracted: %s, %s, %s" % [x, y, z]
          end
          peak.set_coords(x, y, z)
        end
      }
      peak.groups = (groups || [])  # need this line, or YAML will insert object ID
      peak
    
    end
  
  end
  
end