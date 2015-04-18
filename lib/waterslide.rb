module Waterslide
  module RightShiftOverride
    def >> (pipe)
      instantiated(pipe).receive_from(self)
    end

    private
    def instantiated(pipe)
      pipe.is_a?(Class) ? pipe.new : pipe
    end
  end

  module Pipe
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
      @incoming.each do |one|
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

    def pipe_one(thing)
      # identity function by default; including classes should override this
      yield thing
    end
  end

  class NoOp
    include Pipe
  end
end
