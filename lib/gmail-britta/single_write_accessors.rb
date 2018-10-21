module GmailBritta
  # This mixin defines a simple convenience methods for creating
  # accessors that can only be written to once for each instance.
  module SingleWriteAccessors
    # @!parse extend SingleWriteAccessors::ClassMethods
    module ClassMethods

      # @return [Array<Symbol>] the single write accessors defined on
      #   this class and every superclass.
      def single_write_accessors
        super_accessors = {}
        if self.superclass.respond_to?(:single_write_accessors)
          super_accessors = self.superclass.single_write_accessors
        end
        super_accessors.merge(direct_single_write_accessors)
      end

      # @return [Array<Symbol>] the criteria single write accessors
      #   defined on this class and every superclass.
      def single_write_criteria
        super_accessors = {}
        if self.superclass.respond_to?(:single_write_criteria)
          super_accessors = self.superclass.single_write_criteria
        end
        super_accessors.merge(direct_single_write_criteria)
      end

      # Defines a string-typed filter accessor DSL method.  Generates
      # the `[name]`, `get_[name]` and `output_[name]` methods.
      # @param name [Symbol] the name of the accessor method
      # @param gmail_name [String] the name of the attribute in the
      #   gmail Atom export
      def single_write_accessor(name, gmail_name, &block)
        direct_single_write_accessors[name] = gmail_name
        ivar = ivar_name(name)
        define_method(name) do |words|
          if instance_variable_get(ivar) and instance_variable_get(ivar) != []
            raise "Only one use of #{name} is permitted per filter"
          end
          instance_variable_set(ivar, words)
        end
        get(name, ivar)
        string_defined(name, ivar)
        if block_given?
          define_method("output_#{name}") do
            instance_variable_get(ivar) && block.call(instance_variable_get(ivar)) unless instance_variable_get(ivar) == []
          end
        else
          output(name, ivar)
        end
      end

      # Defines a string-typed accessor DSL filter criteria
      # method. This is a convenience method to more easily allow us
      # to merge filters for chaining.
      def define_criteria(name, gmail_name, &block)
        direct_single_write_criteria[name] = gmail_name
        single_write_accessor(name, gmail_name, &block)
      end

      # Defines a boolean-typed accessor DSL filter criteria method.
      def define_boolean_criteria(name, gmail_name, &block)
        direct_single_write_criteria[name] = gmail_name
        single_write_boolean_accessor(name, gmail_name, &block)
      end

      # Defines a boolean-typed filter accessor DSL method. If the
      # method gets called in the filter definition block, that causes
      # the value to switch to `true`.
      # @note There is no way to turn these boolean values back off in
      #   Gmail's export XML.
      # @param name [Symbol] the name of the accessor method
      # @param gmail_name [String] the name of the attribute in the
      #   gmail Atom export
      def single_write_boolean_accessor(name, gmail_name)
        direct_single_write_accessors[name] = gmail_name
        ivar = ivar_name(name)
        define_method(name) do |*args|
          value = args.length > 0 ? args[0] : true
          if instance_variable_get(ivar)
            raise "Only one use of #{name} is permitted per filter"
          end
          instance_variable_set(ivar, value)
        end
        get(name, ivar)
        output(name, ivar)
        boolean_defined(name, ivar)
      end


      private
      def ivar_name(name)
        :"@#{name}"
      end

      def get(name, ivar)
        define_method("get_#{name}") do
          instance_variable_get(ivar)
        end
      end

      def output(name, ivar)
        define_method("output_#{name}") do
          instance_variable_get(ivar)
        end
      end

      def string_defined(name, ivar)
        define_method("defined_#{name}?") do
          !self.send("output_#{name}").nil?
        end
      end

      def boolean_defined(name, ivar)
        define_method("defined_#{name}?") do
          instance_variable_defined?(ivar)
        end
      end

      def direct_single_write_accessors
        @direct_single_write_accessors ||= {}
      end

      def direct_single_write_criteria
        @direct_single_write_criteria ||= {}
      end
    end

    # @!visibility private
    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end
