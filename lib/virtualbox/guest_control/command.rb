module VirtualBox
  module GuestControl

    class Command < Clamp::Command
      option ["-u", "--username"], "USERNAME", "username to log in as"
      option ["-p", "--password"], "PASSWORD", "password to log in as"
      option ["-t", "--timeout"], "TIMEOUT", "timeout in seconds"
      option ["-b", "--vboxmanage"], "PATH", "path to VBoxManage"

      def machine
        VirtualBox::GuestControl::Machine.find_by_name(name).tap do |machine|
          raise "No such machine #{name}" unless machine.present?
          machine.username = username
          machine.password = password
          machine.vbox_manage = vboxmanage unless vboxmanage.nil?
          machine.default_timeout = timeout unless vboxmanage.nil?
        end
      end

      subcommand "start", "start up the given VM" do
        parameter "NAME", "name of virtual machine"

        def execute
          if machine.can_start?
            machine.start!
          else
            puts "Machine can't start because it is currently: #{machine.status}"
          end
        end
      end

      subcommand "shutdown", "shutdown the given VM" do
        parameter "NAME", "name of virtual machine"

        def execute
          if machine.can_shutdown?
            machine.shutdown!
          else
            puts "Machine can't shutdown because it is currently: #{machine.status}"
          end
        end
      end

      subcommand "restart", "restart the given VM" do
        parameter "NAME", "name of virtual machine"

        def execute
          virtual_box.restart!
        end
      end

      subcommand "info", "list all known info about the VM" do
        parameter "NAME", "name of virtual machine"

        def execute
          machine.environment.each do |key, value|
            puts [key, value].join("\t")
          end
        end
      end

      subcommand "usblist", "list usb devices on host" do
        def execute
          UsbDevice.all.each do |device|
            puts device.to_s
          end
        end
      end

      subcommand "usbdetach", "detach usb devices on host" do
        parameter "NAME", "name of virtual machine"

        def execute
          machine.usb_devices.each do |device|
            device.detach(name)
          end
        end
      end

      subcommand "status", "says if the vm is booted or not" do
        parameter "NAME", "name of virtual machine"

        def execute
          puts machine.status
        end
      end

      subcommand "list", "lists the available VMs" do
        option ["--uuid"], :flag, "show only uuid", :default => false
        option ["--name"], :flag, "show only name", :default => false

        def execute
          VirtualBox::GuestControl::Machine.all.each do |machine|
            if uuid?
              puts machine.uuid
            elsif name?
              puts machine.name
            else
              puts [machine.name, machine.uuid].join("\t")
            end
          end
        end
      end

      subcommand "execute", "execute a given command" do
        parameter "NAME", "name of virtual machine"
        parameter "[COMMAND_PARAMETERS] ...", "command and parameters to pass to the VM", :attribute_name => :command_parameters

        def execute
          image_name = command_parameters.shift
          result = machine.execute image_name, *command_parameters
          if result.success?
            puts result.stdout.read
          else
            puts "Command failed with exit status #{result.exit_code}"
            puts "Standard output:"
            puts result.stdout.read
            puts "Standard error:"
            puts result.stderr.read
          end
        end
      end
    end
  end
end