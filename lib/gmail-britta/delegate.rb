module GmailBritta
  class Delegate
    def initialize(britta, options={})
      @britta = britta
      @log = options[:logger]
      @filter = nil
    end

    def filter(&block)
      GmailBritta::Filter.new(@britta, :log => @log).perform(&block)
    end

    def perform(&block)
      instance_eval(&block)
    end
  end
end
