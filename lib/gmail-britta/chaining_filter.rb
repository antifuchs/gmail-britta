module GmailBritta
  class ChainingFilter < Filter
    attr_reader :parent
    def merged?; @merged ; end

    def initialize(parent)
      @parent = parent
      super(parent.filterset, :log => parent.logger)
    end

    def generate_xml
      ensure_merged_with_parent
      super
    end

    # TODO: Maybe just extend #perform to merge after it's done.
    def log_definition
      return unless @log.debug?

      ensure_merged_with_parent
      super
    end

    def ensure_merged_with_parent
      unless merged?
        @merged = true
        perform_merge(@parent)
      end
    end
  end

  class NegatedChainingFilter < ChainingFilter
    def initialize(parent)
      super
    end

    def perform_merge(filter)
      def load(name, filter)
        filter.send("get_#{name}").reject do |elt|
          instance_variable_get("@#{name}").member?(elt)
        end
      end

      def invert(old)
        old.map! do |addr|
          if addr[0] == '-'
            addr[1..-1]
          else
            '-' + addr
          end
        end
      end

      def deep_invert(has_not, has)
        case
        when has_not.first.is_a?(Hash) && has_not.first[:or]
          has_not.first[:or] += has
          has_not
        when has_not.length > 0
          [{:or => has_not + has}]
        else
          has
        end
      end

      @to += invert(load(:to, filter))
      @from += invert(load(:from, filter))
      @has_not += deep_invert(load(:has_not, filter), load(:has, filter))
    end
  end

  class PositiveChainingFilter < ChainingFilter
    def initialize(parent)
      super
    end

    def perform_merge(filter)
      @has += filter.get_has
      @has_not += filter.get_has_not
    end
  end
end
