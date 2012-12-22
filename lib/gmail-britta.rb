#!/usr/bin/env ruby

# Google mail exclusive filter generator
# Docs: http://groups.google.com/group/gmail-labs-help-filter-import-export/browse_thread/thread/518a7b1634f20cdb#
#       http://code.google.com/googleapps/domain/email_settings/developers_guide_protocol.html#GA_email_filter_main

require 'rubygems'
require 'bundler/setup'
require 'time'
require 'haml'
require 'logger'

require 'gmail-britta/single_write_accessors'
require 'gmail-britta/delegate'
require 'gmail-britta/filter'

module GmailBritta
  class Britta
    def initialize(opts={})
      @filters = []
      @me = opts[:me] || 'me'
      @logger = opts[:logger] || allocate_logger
    end

    def allocate_logger
      logger = Logger.new(STDERR)
      logger.level = Logger::WARN
      logger
    end

    attr_accessor :filters
    attr_accessor :me
    attr_accessor :logger

    def rules(&block)
      GmailBritta::Delegate.new(self, :logger => @logger).perform(&block)
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

  def self.filterset(opts={}, &block)
    (britta = Britta.new(opts)).rules(&block)
    britta
  end
end
