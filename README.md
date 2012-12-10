# Virtualbox::Guestcontrol

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'virtualbox-guestcontrol'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install virtualbox-guestcontrol

## Usage

TODO: Write usage instructions here

bundle exec rvbox execute --username XXX --password YYY "ZZZ" "c:\\windows\system32\\systeminfo.exe" |grep "System Up Time"
bundle exec rvbox execute --username XXX --password YYY "ZZZ" "c:\\windows\system32\\shutdown.exe"  -s -t 0

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
