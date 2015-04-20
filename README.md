# waterslide

Unix-style pipes for Ruby programs

## TL;DR

```ruby
class FacebookFriendsController < ApplicationController
  def index
    render json:
        FacebookFriends.new(current_user) >>
        DeserializeFacebookUsers >>
        MergeWithAttributesFromDatabase >>
        RemoveRecordsNotInDatabase >>
        Serialize
  end
end
```

## Wat

A common problem in programming is the need to perform a series of transformations on data. Ruby enumerables have lots of nice functional-style methods (`map`, `reduce`) to make this easy, but in some cases this approach breaks down.

Let's say you're building a social app where users log in with Facebook. You want to have a page where users can see which of their Facebook friends are using your site.

Doing this requires calling the Facebook API to get the current user's friends, merging the data from Facebook with the user data in your own database, filtering out the Facebook users who don't have accounts on your site, and serializing the remaining users to HTML or JSON so you can render them on your page.

The usual solution might look something like this:

```ruby
Facebook.friends_of(current_user)
  .map    { |json| FacebookUserDeserializer.deserialize(json) }
  .map    { |user| user.merge_attributes User.find_by_facebook_id(user.facebook_id) }
  .reject { |user| user.id.nil? }
  .map    { |user| UserSerializer.serialize(user) }
```

Later, you find that the page takes a long time to load for users with many facebook friends, and you isolate the problem to the O(n) `User.find_by_facebook_id` calls, most of which don't actually find a user. Fortunately, that's not hard to fix.

```ruby
facebook_friends = Facebook.friends_of(current_user).map do |friend_datum|
  FacebookUserDeserializer.deserialize(friend_datum)
end
facebook_ids = facebook_friends.map(&:facebook_id)
facebook_friends_from_database = User.where(facebook_id: facebook_ids).to_a
facebook_friends.map! do |friend|
  db_record = facebook_friends_from_database.find do |db_record|
    db_record.facebook_id == friend.facebook_id
  end
  friend.merge_attributes db_record
end
facebook_friends
  .reject { |user| user.id.nil? }
  .map { |user| UserSerializer.serialize(user) }
```

In making the code more efficient, its elegance has been destroyed. Now one of the `map` blocks is dependent on an invariant - the users pulled from the database - and that dependency makes the code harder to read and harder to refactor.

With Waterslide, the various data transformations can easily be broken into their own classes.

```ruby
class FacebookFriends
  include Waterslide::Pipe

  def initialize(current_user)
    @current_user = current_user
  end

  def each(&block)
    @friends ||= Facebook.friends_of(@current_user)
    @friends.each(&block)
  end
end

class DeserializeFacebookUsers
  include Waterslide::Pipe

  def pipe_one(user_json)
    yield User.new#( ... )
  end
end

class MergeWithAttributesFromDatabase
  include Waterslide::Pipe

  def pipe_one(user)
    record = database_records.find do |record|
      record.facebook_id == user.facebook_id
    end

    yield user.merge_attributes record
  end

  def database_records
    @records ||= User.where(facebook_id: incoming.map(&:facebook_id)).to_a
  end
end

class RemoveRecordsNotInDatabase
  include Waterslide::Pipe

  def pipe_one(record)
    yield record if record.id
  end
end

class Serialize
  include Waterslide::Pipe

  def as_json
    map(&:as_json)
  end
end

# ...

FacebookFriends.new(current_user) >>
  DeserializeFacebookUsers >>
  MergeWithAttributesFromDatabase >>
  RemoveRecordsNotInDatabase >>
  SerializeUsers
```

There's obviously a lot more lines of code in the new version, but the sequence of transformations reads naturally, it's easy to insert a new transformation without fear of breaking something, and every step can now be unit-tested individually.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'waterslide'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install waterslide

## Usage

### Defining Pipe Classes

Classes that include `Waterslide::Pipe` can take advantage of Waterslide's functionality by overriding the `pipe_one` or `incoming` methods.

The `pipe_one` method processes a single item from the collection fed into the pipe via the `>>` operator. To pass a value to the next pipe in the pipeline, `yield` it from `pipe_one`

```ruby
class AddOne
  include Waterslide::Pipe

  def pipe_one(n)
    yield n + 1
  end
end
```

Note that you can yield any number of times. You can create a filter by yielding an item only if some criterion is met.

```ruby
class OnlyEvens
  include Waterslide::Pipe

  def pipe_one(n)
    yield n if n % 2 == 0
  end
end

class Unique
  include Waterslide::Pipe

  def pipe_one(item)
    yield item unless seen.include? item
    seen.add item
  end

  def seen
    @seen ||= Set.new
  end
end
```

By yielding more than once, you can expand a list. The following pipe takes a list of classes and outputs the classes and all their ancestors:

```ruby
class AndAncestorClasses
  include Waterslide::Pipe

  def pipe_one(klass)
    yield klass
    while klass = klass.superclass
      yield klass
    end
  end
end
```

If you need to reduce the incoming list, override the `incoming` method. Calling `super` in this method will return the list being piped in. Whatever is returned from `incoming` will be iterated over when calling `each` or another Enumerable method on the pipe.

```ruby
class Sort
  include Waterslide::Pipe

  def incoming
    super.sort
  end
end
```

It's not recommended to override both `incoming` and `pipe_one`, as the interaction between these is subject to change in future versions of Waterslide. You probably shouldn't be both mapping and reducing in the same pipe anyway.

### Using Pipe Classes

As you may have gathered from the examples, you can link pipes together into a pipeline using the `>>` operator.

> ***Ruby has a `>>` operator? What the hell is that?***
>
> It's a clone of C's operator that shifts integers some number of bits to the right. Not many people use Ruby for systems programming or cryptography, so bitshifts aren't very common in Ruby code, although the `<<` operator has a cameo in Array as a near-synonym for `push`.

The value of an expression like `Pipe1 >> Pipe2 >> Pipe3` is an instance of the last class in the pipeline - in this example, `Pipe3`.Pipes include `Enumerable`, so they have the nondestructive methods of other Enumerables like `Array`: `each`, `count`, `include?` and so on. You can get at the whole array with the `all` method.

That leaves one remaining question: how do we get enumerables *into* the pipeline? The most straightforward way is:

```ruby
Waterslide::Pipe[your_data] >> Pipe2 >> # ...
```

This creates a no-op pipe which simply hands off your data to `Pipe2`. However, the first object in the pipeline can be anything that implements the `each` method and Waterslide's `>>` operator. The `each` you'll have to do yourself, but you can get `>>` with a simple `include`:

```ruby
class MyPipe
  include Waterslide::RightShiftOverride

  def each(&block)
    @data.each(&block)
  end
end
```

## Serving Suggestions

If you like syntactic sugar on your cerealizables, you may want to monkey-patch Array with the Waterslide right-shift operator override. That will let you do stuff like this:

```ruby
[1, 2, 3] >> MultiplyByTwo # => [2, 4, 6]
```

Here's how to do the monkey-patch:

```ruby
class Array
  include Waterslide::RightShiftOverride
end
```

You should probably only do this if everyone on your team is on board with Waterslide and knows how to use it; otherwise, they'll have a hell of time deciphering your code.

## Contributing

1. Fork it ( https://github.com/benchristel/waterslide/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
