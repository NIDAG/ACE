module NIDAG
  
  class Term < ActiveRecord::Base
    
    has_many :tags, :dependent => :destroy
    has_many :articles, :through => :tags
    #has_many :active_articles, :through => :tags, :class_name => "Article", :source => :article, :conditions => ['articles.active = ?', 1]
    
    # Call this to update the mapping between Term and Articles via Tags.
    # Save argument specifies whether or not to save to the DB or just return.
    # Mainly useful for newly-generated phrases; for single-word terms,
    # syncing is already done during term tagging.
    def sync(save=true)
      counts = {}
      ArticleText.find_by_sql("SELECT article_id, text FROM article_texts WHERE text LIKE '%#{name}%'").each { |at|
        counts[at.article_id.to_i] = at.text.scan(/#{name}/).size
      }
      # replace existing Tags
      self.tags = []
      counts.each { |t, count|
        self.tags.build({:count => count, :article_id => t, :term_id=>id})
      }
      self.save if save
      self
    end
  end
  
end