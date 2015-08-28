# TracerClient

Library for logging errors and ActiveRecord object changes to Tracer.
 
Tracer is a web application for accumulating, showing and analyzing of a vital application information.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tracer_client'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tracer_client

## Usage

Methods for debugging:

```ruby
Log.debug('Debug message') # log simple message
Log.debug({a: 2, b: 5})    # log hash values
Log.debug(any_object)      # log any object
```

Log some info with severity level. Each method requires message text and log tags and accepts optional data. 
```ruby
Log.info('Order created', 'order create', id: id)
Log.warn('Order shipping too long!', 'order shipping', id: id)
Log.error('Order was not paid', 'order payment', id: id)
```

Log catched exception
```ruby
begin
    raise 'Some exception'
rescue => e
    Log.exception(e, 'Unable to send request', 'request', request_data: data)
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/galanin/tracer_client.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

