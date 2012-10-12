#!/usr/bin/env ruby

# Google mail exclusive filter generator
# Docs: http://groups.google.com/group/gmail-labs-help-filter-import-export/browse_thread/thread/518a7b1634f20cdb#
#       http://code.google.com/googleapps/domain/email_settings/developers_guide_protocol.html#GA_email_filter_main

require 'rubygems'
require 'bundler/setup'
require 'time'
require 'haml'
require 'logger'

$log = Logger.new(STDERR)
$log.level = Logger::INFO

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

  def self.included(base)
    base.extend(ClassMethods)
  end
end

class GmailBritta
  def initialize(opts={})
    @filters = []
    @me = opts[:me] || 'me'
  end

  attr_accessor :filters
  attr_accessor :me

  def self.filterset(opts={}, &block)
    (britta = GmailBritta.new(opts)).rules(&block)
    britta
  end

  def rules(&block)
    Delegate.new(self).perform(&block)
  end

  class Delegate
    def initialize(britta)
      @britta = britta
      @filter = nil
    end

    def filter(&block)
      Filter.new(@britta).perform(&block)
    end

    def perform(&block)
      instance_eval(&block)
    end
  end

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
      $log.debug " Filter spec #{filter.inspect} + #{infix.inspect} => #{str.inspect}"
      str
    end

    def me
      @britta.me
    end

    def initialize(britta)
      @britta=britta
    end

    def log_definition
      $log.debug  "Filter: #{self}"
      Filter.single_write_accessors.each do |name|
        val = instance_variable_get(Filter.ivar_name(name))
        $log.debug "  #{name}: #{val}" if val
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
      $log.debug("  M: oh  #{old_has.inspect}")
      $log.debug("  M: ohn #{old_has_not.inspect}")

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
      $log.debug("  M: h #{@has.inspect}")
      $log.debug("  M: nhn #{@has_not.inspect}")
    end

    def otherwise(&block)
      filter = Filter.new(@britta).perform(&block)
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
      filter = Filter.new(@britta).perform(&block)
      filter.merge_positive_criteria(self)
      filter.log_definition
      filter
    end

    def archive_unless_directed(options={})
      mark_as_read=options[:mark_read]
      tos=(options[:to] || me).to_a
      filter = Filter.new(@britta).perform do
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
end
