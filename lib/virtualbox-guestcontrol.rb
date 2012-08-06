require 'timeout'
require 'shellter'
require 'active_support/configurable'
require 'active_support/time'
require 'active_support/core_ext/hash/indifferent_access'
require 'clamp'

module VirtualBox
  module GuestControl
    class Runner
      include ActiveSupport::Configurable

      self.config[:default_timeout] = 240.seconds
      self.config[:vbox_manage] = Shellter.which("VBoxManage")

      config_accessor :vbox_manage
      config_accessor :name
      config_accessor :default_timeout
      config_accessor :username
      config_accessor :password

      def valid?
        
      end

      def started?
        state[:GuestAdditionsRunLevel] == "2" || state[:GuestAdditionsRunLevel] == "3"
      end

      def shutdown?
        ["poweroff", "aborted", "saved"].include?(state[:VMState])
      end

      def shutdown!(force = false)
        return if shutdown?

        detach_usb_devices

        if force
          Shellter.run(vbox_manage, "controlvm", ":name", "poweroff", :name => name)
          wait_until { shutdown? }
        else
          begin
            Shellter.run(vbox_manage, "controlvm", ":name", "acpipowerbutton", :name => name)
            wait_until { shutdown? }
          rescue TimeoutError
            shutdown_machine(true)
          end
        end
      end

      def start!
        return if started?
        Shellter.run!(vbox_manage, "startvm", ":name", :name => name)
        wait_until { started? }
      end

      def restart!
        shutdown!
        start!
      end

      # VBoxManage guestcontrol     <vmname>|<uuid>
      #                             exec[ute]
      #                             --image <path to program>
      #                             --username <name> --password <password>
      #                             [--dos2unix]
      #                             [--environment "<NAME>=<VALUE> [<NAME>=<VALUE>]"]
      #                             [--timeout <msec>] [--unix2dos] [--verbose]
      #                             [--wait-exit] [--wait-stdout] [--wait-stderr]
      #                             [-- [<argument1>] ... [<argumentN>]]
      def execute(command, *arguments)
        with_started_machine do
          options = arguments.extract_options!
          params = ["guestcontrol", ":name", "execute", "--image", ":command"]

          options[:name] = name
          options[:command] = command

          if username
            params += ["--username", ":username"]
            options[:username] = username
          end

          if password
            params += ["--password", ":password"]
            options[:password] = password
          end

          # params += ["--timeout", ":timeout"]
          params += ["--wait-exit", "--wait-stdout"]
          # options[:timeout] = default_timeout.to_s

          unless arguments.empty?
            params += ["--"] + arguments
          end

          params << options
          
          result = Shellter.run(vbox_manage, *params)
          puts result.stdout.read

        end
      end

      def state
        result = Shellter.run!(vbox_manage, "showvminfo", ":name", "--machinereadable", :name => name)
        {}.with_indifferent_access.tap do |map|
          result.stdout.read.lines.each do |line|
            name, value = line.strip.split("=").map { |y| y.gsub(/(^"|"$)/, "") }
            map[name] = value
          end
        end
      end
      
      class UsbDevice
        class << self
          def parse(output, vbox_manage)
            [].tap do |devices|
              device = nil
              output.lines.each do |line|
                if device
                  if line.strip.blank?
                    devices << device
                    device = nil
                  else
                    key, value = line.split(":")
                    key = key.strip.gsub(" ", "_").underscore
                    value = value.strip
                    device.send(:"#{key}=", value)
                  end
                else
                  next unless line =~ /UUID:/                  
                  value = line.split(":").last.strip
                  device = new(value, vbox_manage)
                end
              end
            end
          end
        end
        
        attr_accessor :uuid, :vendor_id, :product_id, :revision
        attr_accessor :manufacturer, :product, :address, :current_state
        attr_accessor :serial_number
        attr_accessor :vbox_manage
        
        def initialize(uuid, vbox_manage)
          self.vbox_manage = vbox_manage
          self.uuid = uuid
        end
        
        def detach(name)
          result = Shellter.run(vbox_manage, "controlvm", ":name", "usbdetach", ":uuid", :name => name, :uuid => uuid)          
        end
        
        def attach(name)
          Shellter.run!(vbox_manage, "controlvm", ":name", "usbattach", ":uuid", :name => name, :uuid => uuid)
        end
        
        def to_s
          "#{product} (#{uuid}): #{current_state}"
        end
      end
      
      def detach_usb_devices
        self.class.usb_devices.each do |device|
          device.detach(name)          
        end
      end
      
      def attach_usb_devices
        self.class.usb_devices.each do |device|
          device.attach(name)          
        end        
      end
      
      VM_MATCHER = /^"([^"]*)" \{(.*)\}$/
      
      class << self
        def virtual_machines
          result = Shellter.run!(vbox_manage, "list", "vms")
          result.stdout.read.lines.map do |line|
            line.scan(VM_MATCHER).first
          end
        end
        
        def usb_devices
          result = Shellter.run!(vbox_manage, "list", "usbhost")
          UsbDevice.parse(result.stdout, vbox_manage)
        end
      end

      private

      def wait_until
        Timeout::timeout(default_timeout) do
          loop do
            result = yield
            if result
              break
            else
              sleep 5
            end
          end
        end
      end

      def with_started_machine(shutdown_after = false)
        begin
          start!
          yield
        ensure
          shutdown! if shutdown_after
        end
      end
    end
  end
end