module GmailBritta
  class FilterSet
    def initialize(opts={})
      @filters = []
      @me = opts[:me] || 'me'
      @logger = opts[:logger] || allocate_logger
    end

    # Currently defined filters
    # @see Delegate#filter
    # @see GmailBritta::Filter#otherwise
    # @see GmailBritta::Filter#also
    # @see GmailBritta::Filter#archive_unless_directed
    attr_accessor :filters

    # The list of emails that belong to the user running this {FilterSet} definition
    # @see GmailBritta.filterset
    attr_accessor :me

    # The logger currently being used for debug output
    # @see GmailBritta.filterset
    attr_accessor :logger

    # Run the block that defines the filters in {Delegate}'s `instance_eval`. This method will typically only be called by {GmailBritta.filterset}.
    # @api private
    # @yield the filter definition block in {Delegate}'s instance_eval.
    def rules(&block)
      Delegate.new(self, :logger => @logger).perform(&block)
    end

    # Generate ATOM XML for the defined filter set and return it as a String.
    # @return [String] the generated XML, ready for importing into Gmail.
    def generate
      engine = Haml::Engine.new(<<-ATOM)
!!! XML
%feed{:xmlns => 'http://www.w3.org/2005/Atom', 'xmlns:apps' => 'http://schemas.google.com/apps/2006'}
  %title Mail Filters
  %id tag:mail.google.com,2008:filters:
  %updated #{Time.now.utc.iso8601}
  %author
    %name Andreas Fuchs
    %email asf@boinkor.net
  - filters.each do |filter|
    != filter.generate_xml
ATOM
      engine.render(self)
    end

    # A class whose sole purpose it is to be the `self` in a {FilterSet} definition block.
    class Delegate

      # @api private
      def initialize(britta, options={})
        @britta = britta
        @log = options[:logger]
        @filter = nil
      end

      # Create, register and return a new {Filter} without any merged conditions
      # @yield [] the {Filter} definition block, with the new {Filter} instance as `self`.
      # @return [Filtere] the new filter.
      def filter(&block)
        GmailBritta::Filter.new(@britta, :log => @log).perform(&block)
      end

      # Evaluate the {FilterSet} definition block with the {Delegate} object as `self`
      # @api private
      # @note this method will typically only be called by {FilterSet#rules}
      # @yield [ ] that filterset definition block
      def perform(&block)
        instance_eval(&block)
      end
    end

    private
    def allocate_logger
      logger = Logger.new(STDERR)
      logger.level = Logger::WARN
      logger
    end
  end
end
