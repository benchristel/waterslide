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
  .map { |friend_datum| FacebookUserDeserializer.deserialize(friend_datum) }
  .map { |user| user.merge_attributes User.find_by_facebook_id(user.facebook_id) }
  .reject { |user| user.id.nil? }
  .map { |user| UserSerializer.serialize(user) }
```

Later, you find that the page takes a long time to load for users with many facebook friends, and you isolate the problem to the O(n) `User.find_by_facebook_id` calls, most of which don't actually find a user. Fortunately, that's not hard to fix.

```ruby
facebook_friends = Facebook.friends_of(current_user).map do |friend_datum|
  FacebookUserDeserializer.deserialize(friend_datum)
end
facebook_ids = facebook_friends.map(&:facebook_id)
facebook_friends_from_database = User.where(facebook_id: facebook_ids)
facebook_friends.map! do |friend|
  db_record = facebook_friends_from_database.find do |db_record|
    db_record.facebook_id == friend.facebook_id
  end
  friend.merge_attributes db_record
end
facebook_friends.map do |user|
  UserSerializer.serialize(user)
end
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

  def receive_enumerable(users)
    @database_records = User.where(facebook_id: users.map(&:facebook_id)).to_a
  end

  def pipe_one(user)
    record = @database_records.find do |record|
      record.facebook_id == user.facebook_id
    end

    yield user.merge_attributes record
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

There's obviously a lot more lines of code in the new version, but the sequence of transformations reads naturally, and, perhaps more importantly, every step can now be unit-tested individually.

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

TODO: Write usage instructions here

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
