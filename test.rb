gem 'minitest'
require 'minitest/autorun'
require_relative '../waterslide'

class NoOp
  include Pipe
end

class AddOne
  include Pipe

  def pipe_one(thing)
    yield thing + 1
  end
end

class Duplicate
  include Pipe

  def pipe_one(thing)
    yield thing
    yield thing
  end
end

class Add
  include Pipe

  def initialize(n)
    @increment = n
  end

  def pipe_one(thing)
    yield thing + @increment
  end
end

class OnlyEvens
  include Pipe

  def pipe_one(n)
    yield n if n % 2 == 0
  end
end

class TestWaterslide < MiniTest::Unit::TestCase
  def test_piping_a_scalar_through_no_op
    assert_equal 1, (Pipe[1] >> NoOp).first
  end

  def test_piping_a_scalar_through_multiple_no_ops
    assert_equal 1, (Pipe[1] >> NoOp >> NoOp).first
  end

  def test_piping_a_scalar_through_add_one
    assert_equal 2, (Pipe[1] >> AddOne).first
  end

  def test_piping_a_scalar_through_multiple_add_ones
    assert_equal 3, (Pipe[1] >> AddOne >> AddOne).first
  end

  def test_piping_an_array_through_no_op
    assert_equal [1,2,3], (Pipe[[1,2,3]] >> NoOp).all
  end

  def test_piping_an_array_through_add_one
    assert_equal [2,3,4], (Pipe[[1,2,3]] >> AddOne).all
  end

  def test_piping_an_array_through_multiple_add_ones
    assert_equal [3,4,5], (Pipe[[1,2,3]] >> AddOne >> AddOne).all
  end

  def test_piping_an_array_through_duplicate
    assert_equal [1,1,2,2,3,3], (Pipe[[1,2,3]] >> Duplicate).all
  end

  def test_piping_an_array_through_a_filter
    assert_equal [2,4,6], (Pipe[[1,2,3,4,5,6]] >> OnlyEvens).all
  end

  def test_piping_an_array_through_add
    assert_equal [4,5,6], (Pipe[[1,2,3]] >> Add.new(3)).all
  end

  def test_that_pipes_are_enumerables
    assert (Pipe[[1,2,3]] >> Add.new(3)).include? 4
    assert_equal 3, (Pipe[[1,2,3]] >> Add.new(3)).count
  end
end