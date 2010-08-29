# Monkey patches to core Ruby classes go in this file
class String
  
  # Convert alphanumeric representation of number into integer.
  # Returns nil if string isn't a valid number in range 1 - 100.
  # Should eventually expand up to 1000, but 100 probably captures > 95% of studies.
  def to_number
    small = %w[zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen]
    tens = %w[zzzz zzzz twenty thirty forty fifty sixty seventy eighty ninety]
    elems = self.downcase.split('-')
    n = 0
    elems.each { |e|
      n += small.index(e) || 0
      n += ((ind = tens.index(e)).nil? ? 0 : ind*10)
    }
    n.zero? ? nil : n
  end
  
end