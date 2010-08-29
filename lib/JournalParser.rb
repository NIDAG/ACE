# encoding: utf-8
module NIDAG
  
  # Parses HTML articles from different journals/publishers.
  # TODO: Classes need massive refactoring; there's redundancy everywhere.
  class JournalParser
  
    # TODO: fix remaining encoding issues. For now, just skip articles that cause exception.
    @@ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
    @@coder = HTMLEntities.new
  
    def initialize
    end
    
    def self.parse(filename)
      @html = decode(File.new(filename).read)
      @article = Article.new
    end
    
    # CONVERT HTML TO UTF-8 AND DECODE ALL ENTITIES
    # HTMLEntities decoder catches most entities, but generates problems with dashes
    # and non-breaking spaces. To make life easier for later regex matching, we 
    # manually replace problematic entities first, then run decoder to handle the rest.
    # This is a bit slower, but helps prevent epic unicode debugging sessions
    # when stuff goes wrong.
    def self.decode(html)
      html = @@ic.iconv(html)
      bad_ent = {'&#8211;'=>'-', '&#150;'=>'-', '&#177;'=>'', 
                  '&#160;'=>'', '&#145;'=>"'", '&#146;' => "'",
                  '&nbsp;'=>' ', '&#8211;'=>'-',
                  '&#xa0;'=>' ', '&#x2212;'=>'-', '&#x3e;'=>' ',
                  '&minus;'=> '-', '&kappa;'=>'kappa' }
      bad_ent.each { |k,v| html = html.gsub(k, v) }
      @@coder.decode(html)
    end
    
    # Validate record -- skip if exists. TODO: allow overwriting
    def self.validate
      if !@article.valid?
        puts "Error: DB record already exists! Skipping..." if VERBOSE
        return false
      end
      true
    end
    
    def self.finalize
      if !SAVE_ALL_ARTICLES and !@article.active
        puts "Article contains zero valid peaks. Skipping..."
        return false
      end
      
      @article.text = HTMLParser.trim(@html.clone, @article.publisher, @article.journal)
      if @article.text.nil? or @article.text == ""
        puts "Error: no text found! Please check article. Skipping..."
        return false
      end
      puts "Finalizing and saving to database..." if VERBOSE 
      @article.sample_size = HTMLParser.estimate_subjects(@article.text) if ESTIMATE_SAMPLE_SIZE
      @article.map_terms(HTMLParser.count_words(@article.text)) if TAG_ARTICLES
      @article.save!
    end
    
  end

  ### Parse Highwire journals
  class HighwireParser < JournalParser
  
    def self.parse(filename)
    
      super
      
      # Read and set metadata fields
      metadata = {}
      @html.scan(/<meta name="(citation.*?)"\s+content="(.*?)"/).each { 
        |s| metadata[s[0].intern] = s[1]
      }
      
      @article.author = metadata[:citation_authors].split(',')[0]
      @article.year = metadata[:citation_date].split('/')[2]
      @article.journal = metadata[:citation_journal_title]
      @article.doi = metadata[:citation_doi]
      @article.title = metadata[:citation_title]
      @article.filename = filename
      @article.publisher = 'Highwire'
      @article.metadata = metadata
      @article.pubmed_metadata = MetaDataParser.pub_med(@article.doi) if SAVE_PUBMED_METADATA
      
      # validate...
      return if !validate
    
      # Process tables -- tricky because need to match article to table files.
      # For now, we assume filename is the same except for "T?" string appended at end.
      @article.doi.nil? ? (return nil) : doi = @article.doi.split('/')[-1]
      filename = File.basename(filename, '.html')
      Dir["#{CONTENT_DIR}/#{TABLE_DIR}/#{filename}_T*"].each { |f|
        tid = f[/T(\d+)/,1]
        #fname = f[/^(.*?)\.html/,0]
        puts "Parsing Table #{tid}..." if VERBOSE
      
        # Decode HTML and strip HTML entities.
        html = decode(File.new(f).read)
                
        doc = Nokogiri::HTML(html, nil, 'UTF-8') || next
      
        # Use cellspacing attribute as a marker for table start.
        t = doc.xpath('//table[@cellspacing=10]')[0]
      
        # For JNeurophysiology, we need to start a row deeper, because they use a weird format...
        head_row = @article.journal == 'Journal of Neurophysiology' ? 1 : 0
      
        # Get number of columns in table
        ncol = 0
        next if t.nil? or t.xpath('tr')[head_row].nil?
        t.xpath('tr')[head_row].xpath('td').each { |c|
          ncol += (c['colspan'] || 1).to_i
        }
      
        # Initialize grid and populate with values
        data = DataGrid.new(0,ncol)
        begin
          nrows = t.xpath('tr').size
          t.xpath('tr')[head_row,nrows-1].each { |r|
            r.xpath('td').each { |c|
              r_num, c_num = (c['rowspan'] || 1).to_i, (c['colspan'] || 1).to_i
              data.add_val(c.content.gsub(/<\/?[^>]*>/, "").strip, r_num, c_num)
            }
          }
        rescue
          "Error populating DataGrid!"
          next
        end
      
        # Create table from data
        begin
          table = TableParser.parse(data.to_a)
        rescue
          puts "Error processing table!"
          next
        end
        next if table.nil?
      
        # Set other attributes
        table.number = tid.to_i
        title = html.gsub(/(<B>|<\/B>)/,'').scan(/<BR>Table\s\d+(.*?)<P>/)[0]
        table.title = title[0] if !title.nil?
        caption = html.scan(/tblfn\s-->(.*?)<P>/)[0]
        table.caption = caption[0] if !caption.nil?
        @article.active = 1 unless table.peaks.empty?
      
        # Add table to Article
        @article.tables << table        
      }
      
      finalize
    
    end
  
  end
  
  ### Wiley journals
  class WileyParser < JournalParser
      
      def self.parse(filename)
        
        super
        
        # Read and set metadata fields
        metadata = {}
        @html.scan(/<meta\s.*?name="(citation.*?)"\s+content="(.*?)"/).each { 
          |s| metadata[s[0].intern] = s[1]
        }

        @article.author = metadata[:citation_authors].split(',')[0]
        @article.year = (metadata[:citation_date] ? metadata[:citation_date].split('/')[0] : metadata[:citation_online_date].split('/')[0])
        @article.journal = metadata[:citation_journal_title]
        @article.doi = metadata[:citation_doi]
        @article.title = metadata[:citation_title]
        @article.filename = filename
        @article.publisher = 'Wiley'
        @article.metadata = metadata
        @article.pubmed_metadata = MetaDataParser.pub_med(@article.doi) if SAVE_PUBMED_METADATA
        
        return if !validate

        doc = Nokogiri::HTML(@html, nil, 'UTF-8') || abort("Error reading doc...")
        tid = 0
        doc.xpath('//table[@class="topbotR"]').each { |t|

          tid += 1
          puts "Processing Table #{tid}..."

          # Get number of columns in table
          ncol = 0
          t.xpath('tbody')[0].xpath('tr')[0].xpath('td').each { |c|
            ncol += (c['colspan'] || 1).to_i
          }

          # Initialize grid and populate with values
          data = DataGrid.new(0,ncol)
          begin
            x = t.xpath('thead').xpath('tr') + t.xpath('tbody').xpath('tr')
            x.each { |r|
              cols = r.xpath('td') + r.xpath('th')
              cols.each { |c|
                r_num, c_num = (c['rowspan'] || 1).to_i, (c['colspan'] || 1).to_i
                data.add_val(c.content.gsub(/<\/?[^>]*>/, "").strip, r_num, c_num)
              }
            }
          rescue
            "Error populating DataGrid!"
            next
          end

          # Create table from data
          begin
            table = TableParser.parse(data.to_a)
          rescue => e
            puts "Error processing table!"
            puts e.message
            puts e.backtrace
            next
          end
          next if table.nil?

          # Set other attributes
          table.number = tid
          table.title = t.xpath('caption').xpath('span').text
          @article.active = 1 unless table.peaks.empty?

          # add to Article
          @article.tables << table
        }

        finalize

      end
      
  end
  

  ### Base class for all ScienceDirect journals.
  class ScienceDirectParser < JournalParser
  
    def initialize
    end
  
    def self.parse(filename)
      
      super
      
      # Key metadata fields
      @regex_doi = 'href="http:\/\/dx.doi.org\/(10.1016\/.*?)"\s*target="doilink"'
      begin
        @article.doi = @html.scan(/#{@regex_doi}/)[0][0]
      rescue
        puts "Error: No matching doi found!"
        return
      end
      
      puts "getting metadata..."
      
      # Get metadata from pubmed
      metadata = MetaDataParser.pub_med(@article.doi)
      @article.author = metadata[:FAU].split(',')[0]
      @article.year = metadata[:DP][/\d+/]
      @article.title = metadata[:TI]
      @article.journal = @html[/<title>ScienceDirect - (.*?)\s:/, 1]
      @article.filename = filename
      @article.publisher = 'ScienceDirect'
      @article.pubmed_metadata = metadata if SAVE_PUBMED_METADATA
      
      return if !validate

      puts "processing tables..."
      
      # Parse tables
      doc = Nokogiri::HTML(@html, nil, 'UTF-8') || abort("Error reading doc...")
      tid = 0
      doc.xpath('//table[@rules="groups"]').each { |t|
      
        tid += 1
        puts "Processing Table #{tid}..."
      
        # Get number of columns in table
        ncol = 0
        t.xpath('tbody')[0].xpath('tr')[0].xpath('td').each { |c|
          ncol += (c['colspan'] || 1).to_i
        }
      
        # Initialize grid and populate with values
        data = DataGrid.new(0,ncol)
        begin
          t = t.xpath('thead').xpath('tr') + t.xpath('tbody').xpath('tr')
          t.each { |r|
            cols = r.xpath('td') + r.xpath('th')
            cols.each { |c|
              r_num, c_num = (c['rowspan'] || 1).to_i, (c['colspan'] || 1).to_i
              data.add_val(c.content.gsub(/<\/?[^>]*>/, "").strip, r_num, c_num)
            }
          }
        rescue
          "Error populating DataGrid!"
          next
        end
      
        # Create table from data
        begin
          table = TableParser::parse(data.to_a)
        rescue => e
          puts "Error processing table!"
          puts e.message
          puts e.backtrace
          next
        end
        next if table.nil?
      
        # Set other attributes
        table.number = tid
        @article.active = 1 unless table.peaks.empty?
        
        # add to Article
        @article.tables << table
      }
      
      finalize
    
    end
  
  end

  
end