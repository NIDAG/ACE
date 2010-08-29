module NIDAG
  
  # Retrieve records from DB.
  class Search
  
    def self.term_search(query, opts={})
      sync_phrase(query) if query =~ /\s+/
      Term.find_by_name(query, :include => { :articles => { :tables => :peaks }}).articles
    end
    
    # Sync a phrase with articles to make sure tags are accurate
    def self.sync_phrase(phrase)
      term = Term.find_or_create_by_name(phrase)
      term.sync
    end
      
    # A convenience wrapper for the above methods.
    # Useless for now because we only have term-based searching.
    def self.find(type, query, opts={})
      case 'type'
      when 'term'
        term_search(query, opts)
      else
        []
      end
    end
    
  end

end