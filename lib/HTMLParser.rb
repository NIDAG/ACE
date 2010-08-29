module NIDAG
  
  # Assorted methods for extracting information from HTML/text.
  class HTMLParser

    # Clean up HTML: remove all tags, drop header and footer if possible,
    # depending on journal. Note that any changes to the format of full-text
    # HTML articles for any of these journals will likely break the parser
    # and require updating.
    def self.trim(text, publisher, journal)
      journal = publisher if publisher == 'ScienceDirect'
      case journal
      when 'ScienceDirect'
        text.gsub!(/^.*References<\/a><\/dt><\/dl>\s+<\/div>.*?class="articleText_indent">\s+/m, "@@@BEGIN")
        text.gsub!(/<h3 class="h3">References<\/h3>.*$/m, '@@@END')
      when 'Journal of Neurophysiology'
        text.gsub!(/^.*<A NAME="SEC1">/m, "@@@BEGIN")
        text.gsub!(/<A NAME="(References|BIBL)">.*$/m, '@@@END')
      when 'Human Brain Mapping'
        text.gsub!(/<h3>INTRODUCTION<\/h3>.*?<div class="para">/m, "@@@BEGIN")
        text.gsub!(/<div id="wol-references".*$/m, '@@@END')
      when 'European Journal of Neuroscience'
        text.gsub!(/<h3>Introduction<\/h3>.*?<div class="para">/m, "@@@BEGIN")
        text.gsub!(/<h3>References<\/h3>.*$/m, '@@@END')
      end
      text.gsub!(/<\/?[^>]*>/, " ")  # strip HTML tags
      text.gsub!(/\s+/, ' ') # eliminate redundant whitespace
    
      # Trim references etc. to minimize junk
      text = case journal
      when 'ScienceDirect', 'Journal of Neurophysiology', 'Human Brain Mapping', 'European Journal of Neuroscience'
        text[/@@@BEGIN(.*)@@@END/m, 1]
      else
        text[/References\s+(\w+.*)\s+References/m, 1]  # For other Highwire journals
      end
      text
    end
    
    # Parse a string of HTML or text and return hash of word => num_occurrences.
    def self.count_words(text, stop=nil, strip_tags=false)
      
      puts "Counting words..." if VERBOSE
      # Strip all non alphanumeric characters and iterate through words
      return [] if text.nil?
      words = text.gsub(/[^[a-zA-Z0-9\s]]/, '').downcase.split(/\s+/)
      dict = Hash.new(0)
      words.each { |w| dict[w] += 1 }
      # Remove stopwords
      if !stop.nil?
        stop = File.new(stop).read.split(/\n+/)
        stop.each { |w| dict.delete(w) }
      end
      # Sort in descending order of occurrence
      res = {}
      dict.sort { |a,b| b[1] <=> a[1] }.each { |a| res[a[0]] = a[1] }
      res
    end

    # Takes a hash of token occurrences and divides each value
    # by the total number of occurrences. Round to N digits.
    def self.normalize(tags, digits=6)
      total = tags.values.inject(0) { |sum,e| sum+e }
      tags.each_pair { |k,v|
          tags[k] = ((v.to_f/total)*(10**(digits))).round.to_f/(10**digits)
      }
      tags
    end

    # Takes a set of tagged Articles as input and strips out any tags
    # that don't occur sufficiently frequently. Will implicitly normalize tags if desired.
    # Arguments:
    # * articles: an array of Articles
    # * cutoff: the cutoff frequency for excluding tags
    # * min_freq: proportion of all articles in which a tag must occur at least once in order to be kept
    # * stop: location of file containing stop tags that will be removed irrespective of frequency
    def self.filter(articles, min_freq=0.001, min_docs=50, stop=nil)

      # Stop words
      if !stop.nil?
        abort("Error: stopfile '#{stop}' doesn't exist.") if !File.exists?(stop)
        stop_tags = {}
        File.new(stop).read.split(/\n+/).each { |s| stop_tags[s] = 1 }
      end

      # Generating article counts for all tags...
      words = Hash.new(0)
      articles.each { |a|
       a.counts.keys.each { |k| words[k] += 1 } 
      }
      words.delete_if { |k,v| v < min_docs }
      puts "Keeping #{words.size} words:"
      #words.keys.sort.each { |w| puts "#{w}: #{words[w]}"}
      valid_words = words.keys

      puts "Removing tags that occur with proportion < #{min_freq}..." if VERBOSE
      articles.each { |a|
        a.counts.nil? ? a.counts = a.tags.clone : a.tags = a.counts.clone  # kludge for old version; fix this later.
        n_words =  a.tags.values.inject(0.0) { |sum,e| sum+e }
        common = valid_words & a.tags.keys
        keep = {}
        common.each { |word|
          count = a.tags[word]
          # Filter out one-character words, stop words, and non-alphabetical words. Could turn these into arguments later.
          next if word !~ /[a-z]+/ or word.length < 2 or (!stop_tags.nil? and stop_tags.key?(word)) or count/n_words < min_freq
          keep[word] = count
        }
        a.tags = keep.clone
        a.n_words = n_words
        next if a.tags.empty?
      }
      articles
    end

    # Return mean and sd for an array, adjusting for number of zero values.
    def self.mean_and_sd(arr, ndocs)
     n = 0
     mean = 0.0
     s = 0.0
     arr += Array.new(ndocs - arr.size, 0)
     arr.each { |x|
       n += 1
       delta = x - mean
       mean += (delta / n)
       s += delta * (x - mean)
     }
     sd = Math.sqrt(s/n)
     [mean, sd]
    end
    
    # Search through text for strings indicating number of subjects, then come up with
    # an overall estimate of likely sample size. Currently only works in the range of 1-100 
    # in order to prevent outliers.
    # TODO: Find a better implementation; scanning for long disjunctive string is very slow.
    def self.estimate_subjects(text)
      return nil if text.nil?
      n = text.downcase.scan(/([a-zA-Z0-9\-]+)\s+(healthy|volunteers|subjects|individuals|participants|students|patients|outpatients|undergraduates|adults|young|control|right-handed|neurologically|people)/).map { |m|
        if m[0] =~ /^\d+$/
          m[0].to_i
        else
          m[0].to_number
        end
      }
      # Uncomment to also search for "n = ???"-type strings. Note that this generally seems to add more noise than signal.
      # n += text.downcase.scan(/[\(\s]+n\s*=\s*(\d+)/).map { |m| m[0].to_i }
      
      n.compact!
      return nil if n.empty?  # No estimate
      
      # Produce a single sample size estimate from all the numbers we have:
      # * Ignore all values below 10, because most of these will be references to subsets of subjects (e.g., "4 subjects had excessive head movement...")
      # * Ignore values that are extremely high in either absolute or relative terms
      # * For values that are plausible but still very high, cap at 100
      # * If one value occurs more frequently than all others put together, use that one
      # * Take mean of the remaining values
      sum = n.inject(0) { |sum,e| sum + e }
      n.delete_if { |e| e < 10 or e > 300 or (n.size > 3 and e > (sum-e)) }
      return nil if n.empty?
      n.map! { |e| e > 100 ? 100 : e }
      if n.size > 3
        counts = n.inject(Hash.new(0)) { |h, e| h[e] += 1; h }
        counts.each { |k,v| return k if v > n.size/2 }
      end
      (n.inject(0.0) { |sum,e| sum + e } / n.size).round
    end    
    
  end
  
end