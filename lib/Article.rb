module NIDAG
  
  ### A single journal article.
  class Article < ActiveRecord::Base
    
    has_one :article_text
    has_many :tables
    has_many :tags
    has_many :terms, :through => :tags
    accepts_nested_attributes_for :tags
    accepts_nested_attributes_for :article_text
    
    # Ensure we don't duplicate existing records
    validates_uniqueness_of :doi
    
    # Return Basename of file
    def basename
      File.basename(filename)
    end
    
    # Take a hash of words => counts and map them onto Terms through Tags.
    # For each word, need to figure out whether Term already exists,
    # or whether we should create a new one. Also save total number of words.
    def map_terms(counts)
      puts "Tagging article with all terms in text..." if VERBOSE
      self.n_words = counts.values.inject(0) { |sum,e| sum+e }
      set = counts.keys.map { |k| "'#{k.gsub("'", "\\\\'")}'" }.join(", ")
      exists = {}
      
      Term.find_by_sql("SELECT * FROM terms WHERE name IN (#{set})").each { |t| exists[t.name] = t.id }
      counts.each { |t, count|
        if exists.key?(t)
          self.tags.build({:count => count, :term_id => exists[t] })
        else
          self.tags.build({:count => count}).build_term(:name => t)
        end
      }
      self.save(false)
    end
    
    # Accessors for text field in ArticleText
    def text
      article_text.text
    end
    
    def text=(text)
      self.article_text = ArticleText.new({:text => text})
    end
  
    # Return study in a Caret-compatible CSV format
    def to_caret(save=nil)
      # Header -- same for all studies
      csv = [
        "CSVF-FILE",
        "csvf-section-start,Header",
        "tag,Value",
        "caret-version,5.6",
        "comment,[enter comment]",
        "date,[enter date]",
        "encoding,COMMA_SEPARATED_VALUE_FILE",
        "csvf-section-end,header",
        "csvf-section-start,Cells,12,,,Region,,Cluster size,Groups,Average t value,"      # Could determine number of cells dynamically
        ]
        # Pad each row with empty cells... shouldn't be strictly necessary, but do it anyway
        csv.map! { |row|
          res = Array.new(11,'')
          cells = row.split(",")
          res[0,cells.size] = cells
          res.join(",")
        }
        csv = csv.join("\n")
      
        # Column names
        csv += "\n"
        csv += ["X", "Y", "Z", "Name", "Study Table Number", "Geography", "Area", "Size", "Class", "statistic", "Problems"].join(",")
        csv += "\n"
      
        # Study identifier. Note that journal ID is hard-coded for now as CerCor (CC);
        # eventually, need lookup table with all journals.
        author = @meta['citation_authors'][/^(.*?), /, 1]
        year = @meta['citation_date'].split("/")[2][2,2]
        @study_id = "#{author}_JN#{year}"
      
        # Loop through tables, add coords.
        @tables.each { |t|
          tnum = t.id
          t.peaks.each { |p|
            fields = [p.x, p.y, p.z, study_id, t.id, p.region, "", p.size, p.groups.join("/"), p.statistic, p.problems.join("/")]
            fields.map! { |fld| fld =~ /,/ ? "\"#{fld}\"" : fld }  # Enclose values containing commas in parentheses.
            csv += fields.join(",") + "\n"
          }
        }
        csv += "csvf-section-end,Cells,,,,,,,"
      
        File.new("#{save}/#{@study_id}.foci.csv", 'w').write csv if !save.nil?
        csv
      
    end
  
  end
  
  # Just stores the blobs we don't want to have to retrieve with when doing bulk operations
  class ArticleText < ActiveRecord::Base
    
    belongs_to :article
    
  end
  
end