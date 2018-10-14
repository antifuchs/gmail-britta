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

    protected
    def load_array(name, criteria)
      crit = criteria.delete(name)
      unless crit.is_a?(Array)
        crit = [crit]
      end
      crit.reject do |elt|
        instance_variable_get("@#{name}").member?(elt)
      end
    end
  end

  class NegatedChainingFilter < ChainingFilter
    def initialize(parent)
      super
    end

    def perform_merge(filter)
      criteria = filter.criteria
      @to += invert(load_array(:to, criteria))
      @from += invert(load_array(:from, criteria))
      @subject += invert(load_array(:subject, criteria))
      @has_not += deep_invert(load_array(:has_not, criteria), load_array(:has, criteria))

      if criteria.keys.length > 0
        raise("Did not invert criteria #{criteria.keys} - this is likely a bug in gmail-britta")
      end
    end

    private
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
  end

  class PositiveChainingFilter < ChainingFilter
    def initialize(parent)
      super
    end

    def perform_merge(filter)
      criteria = filter.criteria
      criteria.each do |crit_name, crit_value|
        ivar = "@#{crit_name.to_s}"
        have = self.instance_variable_get(ivar)
        case have
        # merge if we have a set of values that can be merged:
        when Array
          self.instance_variable_set(ivar, have + load_array(crit_name, criteria))
        # adopt the value if we have nothing yet; otherwise, keep ours:
        when NilClass
          self.instance_variable_set(ivar, crit_value)
        end
      end
    end
  end
end
