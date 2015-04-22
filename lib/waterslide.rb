module Waterslide
  module RightShiftOverride
    def >> (filter)
      instantiated(filter).receive_from(self)
    end

    private
    def instantiated(filter)
      filter.is_a?(Class) ? filter.new : filter
    end
  end

  module Filter
    def self.included(base)
      base.class_eval do
        include Enumerable
        include RightShiftOverride
      end
    end

    def self.[] (things)
      things = [things] unless things.respond_to? :each
      NoOp.new.receive_from(things)
    end

    def receive_from(enumerable)
      @incoming = enumerable
      self
    end

    def each
      incoming.each do |one|
        pipe_one(one) { |out| yield out }
      end
    end

    def take
      each { |one| return one }
      return nil # if nothing was yielded
    end

    def all
      all = []
      each { |one| all << one }
      all
    end

    private

    def incoming
      # including classes may override this to do processing on the incoming
      # enumerable as as whole - for instance, to sort it.
      @incoming
    end

    def pipe_one(thing)
      # identity function by default; including classes should override this
      yield thing
    end
  end

  class NoOp
    include Filter
  end
end
