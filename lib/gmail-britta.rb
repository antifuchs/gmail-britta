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
require 'gmail-britta/filter_set'
require 'gmail-britta/filter'
require 'gmail-britta/chaining_filter'

# # A generator DSL for importable gmail filter specifications.
#
# This is the main entry point for defining a filter set (multiple filters). See {.filterset} for details.
module GmailBritta

  # Create a {FilterSet} and run the filter set definition in the block.
  # This is the main entry point for GmailBritta.
  # @option opts :me [Array<String>] A list of email addresses that should be considered as belonging to "you", effectively those email addresses you would expect `to:me` to match.
  # @option opts :logger [Logger] (Logger.new()) An initialized logger instance.
  # @options opts :author [Hash] The author of the gmail filters. The hash has :name and :email keys
  # @yield the filterset definition block. `self` inside the block is the {FilterSet} instance.
  # @return [FilterSet] the constructed filterset
  def self.filterset(opts={}, &block)
    (britta = FilterSet.new(opts)).rules(&block)
    britta
  end
end
