require 'timeout'
require 'shellter'
require 'active_support/configurable'
require 'active_support/time'
require 'active_support/core_ext/hash/indifferent_access'
require 'clamp'
require 'state_machine'

module VirtualBox
  module GuestControl
    autoload :Machine, 'virtualbox/guest_control/machine'
    autoload :UsbDevice, 'virtualbox/guest_control/usb_device'
    autoload :Command, 'virtualbox/guest_control/command'
  end
end