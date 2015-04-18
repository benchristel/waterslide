module Pipe
  def self.[] (things)
    things = [things] unless things.respond_to? :each
    Chute.new.receive_from(things)
  end

  def >> (pipe)
    open(pipe).receive_from(self)
  end

  def receive_from(incoming)
    @incoming = incoming
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

  private

  def pipe_one(thing)
    # identity function by default; including classes should override this
    yield thing
  end

  def open(pipe)
    pipe.is_a?(Class) ? pipe.new : pipe
  end
end

class Chute
  include Pipe

  def >> (pipe)
    open(pipe).receive_from(self)
  end

  def open(pipe)
    pipe.is_a?(Class) ? pipe.new : pipe
  end

  def each(&block)
    @incoming.each(&block)
  end
end


