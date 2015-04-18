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

class TestWaterslide < MiniTest::Unit::TestCase
  def test_piping_a_scalar_through_no_op
    assert_equal 1, (Pipe[1] >> NoOp).take
  end

  def test_piping_a_scalar_through_multiple_no_ops
    assert_equal 1, (Pipe[1] >> NoOp >> NoOp).take
  end

  def test_piping_a_scalar_through_add_one
    assert_equal 2, (Pipe[1] >> AddOne).take
  end

  def test_piping_a_scalar_through_multiple_add_ones
    assert_equal 3, (Pipe[1] >> AddOne >> AddOne).take
  end
  #
  #def test_piping_a_scalar_through_add_one
  #  assert_equal 2, (Pipe[1] >> AddOne).take
  #end
  #
  #def test_piping_an_array_through_no_op
  #  assert_equal [1,2,3], (Pipe[1,2,3] >> NoOp).all
  #end
  #
  #def test_piping_an_array_through_add_one
  #  assert_equal [2,3,4], (Pipe[1,2,3] >> AddOne).all
  #end
end
