module GmailBritta
  class Filter
    include SingleWriteAccessors
    single_write_accessor :has, 'hasTheWord' do |list|
      emit_filter_spec(list)
    end
    single_write_accessor :has_not, 'doesNotHaveTheWord' do |list|
      emit_filter_spec(list)
    end
    single_write_boolean_accessor :archive, 'shouldArchive'
    single_write_boolean_accessor :delete_it, 'shouldTrash'
    single_write_boolean_accessor :mark_read, 'shouldMarkAsRead'
    single_write_boolean_accessor :mark_important, 'shouldAlwaysMarkAsImportant'
    single_write_boolean_accessor :mark_unimportant, 'shouldNeverMarkAsImportant'
    single_write_boolean_accessor :star, 'shouldStar'
    single_write_boolean_accessor :never_spam, 'shouldNeverSpam'
    single_write_accessor :label, 'label'
    single_write_accessor :forward_to, 'forwardTo'

    def initialize(britta, options={})
      @britta = britta
      @log = options[:log]
    end

    def generate_xml
      engine = Haml::Engine.new(<<-ATOM)
%entry
  %category{:term => 'filter'}
  %title Mail Filter
  %content
  - self.class.single_write_accessors.keys.each do |name|
    - gmail_name = self.class.single_write_accessors[name]
    - if value = self.send("output_\#{name}".intern)
      %apps:property{:name => gmail_name, :value => value.to_s}
ATOM
      engine.render(self)
    end

    def self.emit_filter_spec(filter, infix=' ')
      str = ''
      case filter
      when String
        str << filter
      when Hash
        filter.keys.each do |key|
          case key
          when :or
              str << '('
            str << emit_filter_spec(filter[key], ' OR ')
            str << ')'
          when :not
              str << '-('
            str << emit_filter_spec(filter[key], ' ')
            str << ')'
          end
        end
      when Array
        str << filter.map {|elt| emit_filter_spec(elt, ' ')}.join(infix)
      end
      str
    end

    def me
      @britta.me
    end

    def log_definition
      @log.debug  "Filter: #{self}"
      Filter.single_write_accessors.each do |name|
        val = instance_variable_get(Filter.ivar_name(name))
        @log.debug "  #{name}: #{val}" if val
      end
      self
    end

    def perform(&block)
      instance_eval(&block)
      @britta.filters << self
      self
    end

    def merge_negated_criteria(filter)
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

    def otherwise(&block)
      filter = Filter.new(@britta, :log => @log).perform(&block)
      filter.merge_negated_criteria(self)
      filter.log_definition
      filter
    end

    def merge_positive_criteria(filter)
      new_has = (@has || []) + (filter.get_has || [])
      new_has_not = (@has_not || []) + (filter.get_has_not || [])
      @has = new_has
      @has_not = new_has_not
    end

    def also(&block)
      filter = Filter.new(@britta, :log => @log).perform(&block)
      filter.merge_positive_criteria(self)
      filter.log_definition
      filter
    end

    def archive_unless_directed(options={})
      mark_as_read=options[:mark_read]
      tos=(options[:to] || me).to_a
      filter = Filter.new(@britta, :log => @log).perform do
        has_not [{:or => tos.map {|to| "to:#{to}"}}]
        archive
        if mark_as_read
          mark_read
        end
      end
      filter.merge_positive_criteria(self)
      filter.log_definition
      self
    end
  end
end
