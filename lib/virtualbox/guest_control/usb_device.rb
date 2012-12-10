module VirtualBox
  module GuestControl
    class UsbDevice
      include ActiveSupport::Configurable

      class << self
        def all(vbox_manage)
          result = Shellter.run!(vbox_manage, "list", "usbhost")
          parse(result.stdout)
        end

        def parse(output)
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
                  begin
                    device.send(:"#{key}=", value)
                  rescue
                    # this is the version/speed attribute... maybe we should parse it
                    #puts [key, value].join(" => ")
                  end
                end
              else
                next unless line =~ /UUID:/
                value = line.split(":").last.strip
                device = new(value)
              end
            end
          end
        end
      end

      attr_accessor :uuid, :vendor_id, :product_id, :revision
      attr_accessor :manufacturer, :product, :address, :current_state, :port
      attr_accessor :serial_number
      attr_accessor :vbox_manage

      def initialize(uuid)
        self.uuid = uuid
      end

      def to_s
        "#{product} (#{uuid}): #{current_state}"
      end

      def state
        current_state
      end
    end
  end
end