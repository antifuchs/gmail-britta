module GmailBritta
  module SingleWriteAccessors
    module ClassMethods
      def ivar_name(name)
        "@#{name}".intern
      end

      def single_write_accessors
        @single_write_accessors ||= {}
      end

      def single_write_accessor(name, gmail_name, &block)
        single_write_accessors[name] = gmail_name
        ivar_name = self.ivar_name(name)
        define_method(name) do |words|
          if instance_variable_get(ivar_name)
            raise "Only one use of #{name} is permitted per filter"
          end
          instance_variable_set(ivar_name, words)
        end
        define_method("get_#{name}") do
          instance_variable_get(ivar_name)
        end
        if block_given?
          define_method("output_#{name}") do
            instance_variable_get(ivar_name) && block.call(instance_variable_get(ivar_name))
          end
        else
          define_method("output_#{name}") do
            instance_variable_get(ivar_name)
          end
        end
      end

      def single_write_boolean_accessor(name, gmail_name)
        single_write_accessors[name] = gmail_name
        ivar_name = self.ivar_name(name)
        define_method(name) do |*args|
          value = args.length > 0 ? args[0] : true
          if instance_variable_get(ivar_name)
            raise "Only one use of #{name} is permitted per filter"
          end
          instance_variable_set(ivar_name, value)
        end
        define_method("get_#{name}") do
          instance_variable_get(ivar_name)
        end
        define_method("output_#{name}") do
          instance_variable_get(ivar_name)
        end
      end
    end

    # @!visibility private
    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end
