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
      old_has_not = Marshal.load(Marshal.dump((filter.get_has_not || []).reject { |elt|
            @has.member?(elt)
          }))
      old_has = Marshal.load( Marshal.dump((filter.get_has || []).reject { |elt|
            @has.member?(elt)
          }))
      @log.debug("  M: oh  #{old_has.inspect}")
      @log.debug("  M: ohn #{old_has_not.inspect}")

      @has_not ||= []
      @has_not += case
                  when old_has_not.first.is_a?(Hash) && old_has_not.first[:or]
                    old_has_not.first[:or] += old_has
                    old_has_not
                  when old_has_not.length > 0
                    [{:or => old_has_not + old_has}]
                  else
                    old_has
                  end
      @log.debug("  M: h #{@has.inspect}")
      @log.debug("  M: nhn #{@has_not.inspect}")
    end
  end

  class PositiveChainingFilter < ChainingFilter
    def initialize(parent)
      super
    end

    def perform_merge(filter)
      new_has = (@has || []) + (filter.get_has || [])
      new_has_not = (@has_not || []) + (filter.get_has_not || [])
      @has = new_has
      @has_not = new_has_not
    end
  end
end
