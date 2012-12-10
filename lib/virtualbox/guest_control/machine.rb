module VirtualBox
  module GuestControl
    class Machine
      VM_MATCHER = /^"([^"]*)" \{(.*)\}$/

      include ActiveSupport::Configurable

      self.config[:default_timeout] = 240.seconds
      self.config[:vbox_manage] = Shellter.which("VBoxManage")

      config_accessor :vbox_manage

      config_accessor :default_timeout
      config_accessor :username
      config_accessor :password

      class << self
        def all
          result = Shellter.run!(vbox_manage, "list", "vms")
          result.stdout.read.lines.map do |line|
            new(*line.scan(VM_MATCHER).first)
          end
        end

        def find_by_uuid(uuid)
          all.detect { |machine| machine.uuid == uuid }
        end

        def find_by_name(name)
          all.detect { |machine| machine.name == name }
        end
      end

      def initialize(name, uuid)
        @name = name
        @uuid = uuid
      end

      attr_accessor :name
      attr_accessor :uuid

      state_machine :initial => :poweroff do

        event :start do
          transition [:saved, :aborted, :poweroff] => :running
        end

        event :shutdown do
          transition :running => :poweroff
        end

        before_transition any => :running do |machine, transition|
          Shellter.run!(machine.vbox_manage, "startvm", ":name", :name => machine.name)
          machine.wait_until { machine.running? }
          machine.wait_until { machine.guest_additions_started? }
        end

        before_transition :running => :poweroff do |machine, transition|
          machine.detach_usb_devices!

          begin
            Shellter.run(machine.vbox_manage, "controlvm", ":name", "acpipowerbutton", :name => machine.name)
            machine.wait_until { machine.poweroff? }
          rescue TimeoutError
            Shellter.run(machine.vbox_manage, "controlvm", ":name", "poweroff", :name => machine.name)
            wait_until { machine.shutdown? }
          end
        end

        state :poweroff do
          def status
            "Powered Off"
          end

          def execute(*arguments)
            with_started_machine do
              execute(*arguments)
            end
          end
        end

        state :aborted do
          def status
            "Aborted"
          end

          def execute(*arguments)
            with_started_machine do
              execute(*arguments)
            end
          end
        end

        state :running do
          def status
            "Running"
          end

          def execute(command, *arguments)

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

            Shellter.run(vbox_manage, *params)
          end
        end

        state :saved do
          def status
            "Saved State"
          end

          def execute(*arguments)
            with_started_machine do
              execute(*arguments)
            end
          end
        end
      end

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

      def state
        environment[:VMState]
      end

      def guest_additions_started?
        guest_additions_run_level >= 2
      end

      def guest_additions_run_level
        environment[:GuestAdditionsRunLevel].to_i
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


      def environment
        result = Shellter.run!(vbox_manage, "showvminfo", ":name", "--machinereadable", :name => name)
        {}.with_indifferent_access.tap do |map|
          result.stdout.read.lines.each do |line|
            name, value = line.strip.split("=").map { |y| y.gsub(/(^"|"$)/, "") }
            map[name] = value
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

      def usb_devices
        UsbDevice.all(vbox_manage)
      end

      def detach_usb_devices!
        usb_devices.each do |usb_device|
          detach!(usb_device)
        end
      end

      def attach_usb_devices!
        usb_devices.each do |usb_device|
          attach!(usb_device)
        end
      end

      def detach!(usb_device)
        Shellter.run(vbox_manage, "controlvm", ":name", "usbdetach", ":uuid", :name => name, :uuid => usb_device.uuid)
      end

      def attach!(usb_device)
        Shellter.run!(vbox_manage, "controlvm", ":name", "usbattach", ":uuid", :name => name, :uuid => usb_device.uuid)
      end
    end
  end
end