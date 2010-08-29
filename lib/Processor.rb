module NIDAG
  
  # Miscellaneous operations involving multiple classes.
  class Processor
    
    # Iterates through top-level content directory, reads each file,
    # tries to identify right parser, and runs.
    def self.parse_content
      
      Dir["#{CONTENT_DIR}/*"].grep(/^[a-zA-Z0-9]+/).map { |f|
        
        text = File.new(f).read
        puts "\n\nProcesssing #{f}..."
        
        # Guess publisher. Kind of crude. Could eventually substitute
        # a lookup list based on journal name.
        begin
          parser =
          case text
          when /^\n+<HTML>\n<HEAD>/
            'Highwire'
          when /^\n+<html><head>/
            'ScienceDirect'
          when /Wiley Online Library<\/title>/
            'Wiley'
          else
            puts "Error: missing or invalid parser for file #{f}. Skipping..."
            next
          end
        rescue
          puts "Error processing #{f}. Skipping..."
          next
        end
        
        puts "Detected publisher: #{parser}" if VERBOSE
        begin
          Object.const_get(parser + 'Parser').parse(f)
        rescue
          puts "An unspecified error occurred. Skipping..."
        end
      }
    end
  
  end
  
end