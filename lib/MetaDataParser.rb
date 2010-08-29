module NIDAG
  
  class MetaDataParser
   
    # Retrieve metadata from PubMed; takes either doi or PMID.
    def self.pub_med(id)
      # for doi, need to retrieve PMID first
      if id =~ /\//
        begin
          pmid = open("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=#{id}[aid]").read[/<Id>(\d+)<\/Id>/,1]
          sleep(0.3) # Per terms of service, rest between queries
        rescue
          "Error getting PMID from PubMed!"
          return false
        end
      end
      
      begin
        doc = open("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=#{pmid.to_i}&retmode=text&rettype=medline").read
      rescue
        "Error retrieving metadata from PubMed for record #{pmid}!"
      end
      
      data = {}
      doc.gsub(/\n\s+/, ' ').scan(/^([A-Z]+)\s*-\s+(.*)/).each { |m|
        field, val = m[0].intern, m[1]
        !data.key?(field) ? data[field] = val : data[field] += "; #{val}"
      }
      data.keys.each { |k| data[k] = '' if data[k].nil? }
      data
    end
    
  end
  
end