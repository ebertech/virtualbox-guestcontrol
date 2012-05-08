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

      self.config[:default_timeout] = 120.seconds
      self.config[:vbox_manage] = Shellter.which("VBoxManage")

      config_accessor :vbox_manage
      config_accessor :name
      config_accessor :default_timeout
      config_accessor :username
      config_accessor :password

      #validate that vbox_manage exists
      #validate that name is a valid name

      def started?
        state[:GuestAdditionsRunLevel] == "2"
      end

      def shutdown?
        ["poweroff", "aborted"].include?(state[:VMState])
      end

      def shutdown!(force = false)
        return if shutdown?
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

          params += ["--wait-stdout"]
          params += ["--timeout", ":timeout"]
          options[:timeout] = default_timeout.to_s

          unless arguments.empty?
            params += ["--", ":arguments"]
            options[:arguments] = arguments.join(" ")
          end

          params << options

          Shellter.run!(vbox_manage, *params)
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

      def with_started_machine
        begin
          start!
          yield
        ensure
          shutdown!
        end
      end
    end
  end
end