module Oyster

  class Wire
    
    attr_reader :source, :dest

    def initialize source, dest
      @source = source    # A hash of the form { place: p, name: n } that says the place to get the 
                          # value, and the name of the value in the log of the most recent job for that place.
      @dest = dest        # A hash of the form { place: p, name: n } that says which place gets the value
                          # and which argument it corresponds to.
    end

  end

end