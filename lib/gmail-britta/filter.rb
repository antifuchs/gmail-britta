module GmailBritta
  # This class specifies the behavior of a single filter
  # definition. Create a filter object in the DSL via
  # {FilterSet::Delegator#filter} or use {Filter#also},
  # {Filter#otherwise} or {Filter#archive_unless_directed} to make a
  # new filter based on another one.
  # @todo this probably needs some explanatory docs to make it understandable.

  class Filter
    include SingleWriteAccessors

    # @!group Methods for use in a filter definition block
    # Archive the message.
    # @!macro [new] bool_dsl_method
    #   @return [void]
    #   @!method $1()
    single_write_boolean_accessor :archive, 'shouldArchive'

    # Move the message to the trash.
    # @macro bool_dsl_method
    single_write_boolean_accessor :delete_it, 'shouldTrash'

    # Mark the message as read.
    # @macro bool_dsl_method
    single_write_boolean_accessor :mark_read, 'shouldMarkAsRead'

    # Mark the message as important.
    # @macro bool_dsl_method
    single_write_boolean_accessor :mark_important, 'shouldAlwaysMarkAsImportant'

    # Do not mark the message as important.
    # @macro bool_dsl_method
    single_write_boolean_accessor :mark_unimportant, 'shouldNeverMarkAsImportant'

    # Star the message
    # @macro bool_dsl_method
    single_write_boolean_accessor :star, 'shouldStar'

    # Never mark the message as spam
    # @macro bool_dsl_method
    single_write_boolean_accessor :never_spam, 'shouldNeverSpam'

    # Assign the given label to the message
    # @return [void]
    # @!method label(label)
    # @param [String] label the label to assign the message
    single_write_accessor :label, 'label'

    # Forward the message to the given label.
    # @return [void]
    # @!method forward_to(email)
    # @param [String] email an email address to forward the message to
    single_write_accessor :forward_to, 'forwardTo'

    # @!method has(conditions)
    # @return [void]
    # Defines the positive conditions for the filter to match.
    # @overload has([conditions])
    #   Conditions ANDed together that an incoming email must match.
    #   @param [Array<conditions>] conditions a list of gmail search terms, all of which must match
    # @overload has({:or => [conditions]})
    #   Conditions ORed together for the filter to match
    #   @param [{:or => conditions}] conditions a hash of the form `{:or => [condition1, condition2]}` - either of these conditions must match to match the filter.
    single_write_accessor :has, 'hasTheWord' do |list|
      emit_filter_spec(list)
    end

    # @!method from(conditions)
    # @return [void]
    # Defines the positive conditions for the filter to match.
    # Uses: <apps:property name='from' value='postman@usps.gov'></apps:property>
    # Instead of: <apps:property name='hasTheWord' value='from:postman@usps.gov'></apps:property>
    single_write_accessor :from, 'from' do |list|
      emit_filter_spec(list)
    end

    # @!method to(conditions)
    # @return [void]
    # Defines the positive conditions for the filter to match.
    # Uses: <apps:property name='to' value='postman@usps.gov'></apps:property>
    # Instead of: <apps:property name='hasTheWord' value='to:postman@usps.gov'></apps:property>
    single_write_accessor :to, 'to' do |list|
      emit_filter_spec(list)
    end

    # @!method has_not(conditions)
    # @return [void]
    # Defines the negative conditions that must not match for the filter to be allowed to match.
    single_write_accessor :has_not, 'doesNotHaveTheWord' do |list|
      emit_filter_spec(list)
    end

    # Filter for messages that have an attachment
    # @macro bool_dsl_method
    single_write_boolean_accessor :has_attachment, 'hasAttachment'
    # @!endgroup

    # Register and return a new filter that matches only if this
    # filter's conditions (those that are not duplicated on the new
    # filter's `has` clause) do not match.
    # @yield The filter definition block
    # @return [Filter] the new filter
    def otherwise(&block)
      filter = Filter.new(@britta, :log => @log).perform(&block)
      filter.merge_negated_criteria(self)
      filter.log_definition
      filter
    end

    # Register and return a new filter that matches a message only if
    # this filter's conditions *and* the previous filter's condition
    # match.
    # @yield The filter definition block
    # @return [Filter] the new filter
    def also(&block)
      filter = Filter.new(@britta, :log => @log).perform(&block)
      filter.merge_positive_criteria(self)
      filter.log_definition
      filter
    end

    # Register (but don't return) a filter that archives the message
    # unless it matches the `:to` email addresses. Optionally, mark
    # the message as read if this filter matches.
    #
    # @note This method returns the previous filter to make it easier to construct filter chains with {#otherwise} and {#also}.
    #
    # @option options [true, false] :mark_read If true, mark the message as read
    # @option options [Array<String>] :to a list of addresses that the message may be addressed to in order to prevent this filter from matching. Defaults to the value given to :me on {GmailBritta.filterset}.
    # @return [Filter] the current (not the newly-constructed filter)
    def archive_unless_directed(options={})
      mark_as_read=options[:mark_read]
      tos=Array(options[:to] || me)
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

    # Create a new filter object
    # @note Over the lifetime of {GmailBritta}, new {Filter}s usually get created only by the {Delegate}.
    # @param [GmailBritta::Britta] britta the filterset object
    # @option options :log [Logger] a logger for debug messages
    def initialize(britta, options={})
      @britta = britta
      @log = options[:log]
    end

    # Return the filter's value as XML text.
    # @return [String] the Atom XML representation of this filter
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

    # Evaluate block as a filter definition block and register `self` as a filter on the containing {FilterSet}
    # @note this method gets called by {Delegate#filter} to create and register a new filter object
    # @yield The filter definition. `self` in the block is the new filter object.
    # @api private
    # @return [Filter] the filter that
    def perform(&block)
      instance_eval(&block)
      @britta.filters << self
      self
    end

    protected

    def merge_negated_criteria(filter)
      old_has_not = Marshal.load(Marshal.dump((filter.get_has_not || []).reject { |elt|
            @has.member?(elt)
          }))
      old_has = Marshal.load( Marshal.dump((filter.get_has || []).reject { |elt|
            @has.member?(elt)
          }))
      old_from = Marshal.load( Marshal.dump((filter.get_from || []).reject { |elt|
            (@from || []).member?(elt)
          }))
      old_to = Marshal.load( Marshal.dump((filter.get_to || []).reject { |elt|
            (@to || []).member?(elt)
          }))

      @log.debug("  M: oh  #{old_has.inspect}")
      @log.debug("  M: ohn #{old_has_not.inspect}")
      @log.debug("  M: of #{old_from.inspect}")
      @log.debug("  M: ot #{old_to.inspect}")

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

      @from = (@from || []) + old_from.select{|a| a[0] == '-'}.map { |addr| addr[1..-1] }.compact
      @from = (@from || []) + old_from.select{|a| a[0] != '-'}.map { |addr| '-' + addr }.compact
      @to = (@to || []) + old_to.select{|a| a[0] == '-'}.map { |addr| addr[1..-1] }.compact
      @to = (@to || []) + old_to.select{|a| a[0] != '-'}.map { |addr| '-' + addr }.compact
      @from = @from.empty? ? nil : @from
      @to = @to.empty? ? nil : @to

      @log.debug("  M: nh #{@has.inspect}")
      @log.debug("  M: nhn #{@has_not.inspect}")
      @log.debug("  M: nf #{@from.inspect}")
      @log.debug("  M: nt #{@to.inspect}")
    end

    def merge_positive_criteria(filter)
      new_has = (@has || []) + (filter.get_has || [])
      new_has_not = (@has_not || []) + (filter.get_has_not || [])
      @has = new_has
      @has_not = new_has_not
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

    # Note a filter definition on the logger.
    # @note for debugging only.
    def log_definition
      return unless @log.debug?
      @log.debug  "Filter: #{self}"
      Filter.single_write_accessors.each do |name, gmail_name|
        val = instance_variable_get(Filter.ivar_name(name))
        @log.debug "  #{name}: #{val}" if val
      end
      self
    end

    # Return the list of emails that the filterset has configured as "me".
    def me
      @britta.me
    end
  end
end
