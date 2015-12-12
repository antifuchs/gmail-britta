require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'bundler/setup'
require 'minitest/unit'
require 'nokogiri'
require 'minitest/autorun'

require 'gmail-britta'

describe GmailBritta do
  def dom(filterset)
    text = filterset.generate
    #puts text
    Nokogiri::XML.parse(text)
  end

  def ns
    {
      'a' => 'http://www.w3.org/2005/Atom',
      'apps' => 'http://schemas.google.com/apps/2006'
    }
  end

  it "runs" do
    fs = GmailBritta.filterset() do
      filter {
          has 'to:asf@boinkor.net'
          label 'ohai'
      }
    end
    filters = fs.generate
    assert(filters, "Should generate something")
    assert(filters.is_a?(String), "Generated filters should be a string")
  end

  it "generates 'label' properties" do
    fs = GmailBritta.filterset() do
      filter {
          has 'to:asf@boinkor.net'
          label 'ohai'
      }
    end

    filters = dom(fs)
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="label"]',ns).length, "Should have exactly one 'label' property")
  end

  it "also generates 'smartLabelToApply' properties" do
    groups = {
      'forums' => :group,
      'Forums' => :group,
      'notifications' => :notification,
      'Notifications' => :notification,
      'updates' => :notification,
      'Updates' => :notification,
      'promotions' => :promo,
      'Promotions' => :promo,
      'social' => :social,
      'Social' => :social
    }

    groups.each do |key, value|
      fs = GmailBritta.filterset() do
        filter {
          has 'to:asf@boinkor.net'
          label 'ohai'
          smart_label key
        }
      end

      filters = dom(fs)
      assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="label"]',ns).length, "Should have exactly one 'label' property")

      smart_labels = filters.xpath('/a:feed/a:entry/apps:property[@name="smartLabelToApply"]',ns)
      assert_equal(1, smart_labels.length, "Should have exactly one 'smartLabelToApply' property")
      smart_label_value = smart_labels.first['value']
      assert_equal("^smartlabel_#{value}", smart_label_value, "Should use the smartlabel_ value")
    end

    err = assert_raises RuntimeError do
      fs = GmailBritta.filterset() do
        filter {
          has 'to:asf@boinkor.net'
          label 'ohai'
          smart_label 'Foobar'
        }
      end
      dom(fs)
    end
    assert_equal('invalid category "Foobar"', err.message)
  end

  it "generates simple 'has' condition xml" do
    filters = dom(
      GmailBritta.filterset() do
        filter {
          has %w{to:asf@boinkor.net}
          label 'ohai'
          archive
        }
      end
    )

    assert_equal(1, filters.xpath('/a:feed/a:entry',ns).length, "Should have exactly one filter entry")
    assert_equal(3, filters.xpath('/a:feed/a:entry/apps:property',ns).length, "Should have two properties")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="label"]',ns).length, "Should have exactly one 'label' property")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="shouldArchive"]',ns).length, "Should have exactly one 'shouldArchive' property")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="hasTheWord"]',ns).length, "Should have exactly one 'has' property")
  end

  it "generates simple 'has_not' condition xml" do
    filters = dom(
      GmailBritta.filterset() do
        filter {
          has_not %w{to:asf@boinkor.net}
          label 'ohai'
          archive
        }
      end
    )

    assert_equal(1, filters.xpath('/a:feed/a:entry',ns).length, "Should have exactly one filter entry")
    assert_equal(3, filters.xpath('/a:feed/a:entry/apps:property',ns).length, "Should have two properties")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="label"]',ns).length, "Should have exactly one 'label' property")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="shouldArchive"]',ns).length, "Should have exactly one 'shouldArchive' property")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="doesNotHaveTheWord"]',ns).length, "Should have exactly one 'has_not' property")
  end

  it "generates simple 'from' condition xml" do
    filters = dom(
      GmailBritta.filterset() do
        filter {
          from %w{asf@boinkor.net}
          label 'ohai'
        }
      end
    )

    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="from"]',ns).length, "Should have exactly one 'from' property")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@value="asf@boinkor.net"]',ns).length, "Should have exactly one 'from' value")
  end

  it "generates an error for multiple accessors" do
    err = assert_raises RuntimeError do
      GmailBritta.filterset() do
        filter {
          from %w{asf@boinkor.net}
          from %w{asf@boinkor.net}
          label 'ohai'
        }
      end
    end
    assert_equal('Only one use of from is permitted per filter', err.message)
  end

  it "generates an error for multiple boolean accessors" do
    err = assert_raises RuntimeError do
      GmailBritta.filterset() do
        filter {
          from %w{asf@boinkor.net}
          archive
          archive
        }
      end
    end
    assert_equal('Only one use of archive is permitted per filter', err.message)
  end

  it "generates multiple 'from' condition xml" do
    filters = dom(
      GmailBritta.filterset() do
        filter {
          from ['asf@boinkor.net', 'abc@boinkor.net']
          label 'ohai'
        }
      end
    )

    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="from"]',ns).length, "Should have exactly one 'from' property")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@value="asf@boinkor.net abc@boinkor.net"]',ns).length, "Should have both addresses in 'from' property")
  end

  it "uses .otherwise for single 'from' condition" do
    filters = dom(
      GmailBritta.filterset() do
        filter {
          from %w{asf@boinkor.net}
          label 'ohai'
        }.otherwise {
          label 'bai'
        }
      end
    )

    assert_equal(2, filters.xpath('/a:feed/a:entry/apps:property[@name="from"]',ns).length, "Should have two 'from' properties")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@value="asf@boinkor.net"]',ns).length, "Should have the address positively exactly once")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@value="-asf@boinkor.net"]',ns).length, "Should have the address negatively exactly once")
  end

  it "uses .also for single 'to' condition" do
    filters = dom(
      GmailBritta.filterset() do
        filter {
          from %w{from@boinkor.net}
          label 'ohai'
        }.also {
          to %w{to@boinkor.net}
        }
      end
    )

    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="from"][@value="from@boinkor.net"]',ns).length, "Should have the from address")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="to"][@value="to@boinkor.net"]',ns).length, "Should have the to address")
  end

  it "doesn't fail issue #4 - correctly-parenthesised nested ANDs" do
    fs = GmailBritta.filterset do
      filter {
        has :or => [['subject:whee', 'from:zot@spammer.com'], 'from:bob@bob.com', 'from:foo@foo.com']
        label 'yay'
      }
    end
    filters = dom(fs)

    filter_text = filters.xpath('/a:feed/a:entry/apps:property[@name="hasTheWord"]',ns).first['value']
    assert_equal('(subject:whee from:zot@spammer.com) OR from:bob@bob.com OR from:foo@foo.com', filter_text)
  end

  it "uses .otherwise for multiple 'from' condition" do
    filters = dom(
      GmailBritta.filterset() do
        filter {
          from ['asf@boinkor.net', 'abc@boinkor.net']
          label 'ohai'
        }.otherwise {
          label 'bai'
        }
      end
    )

    assert_equal(2, filters.xpath('/a:feed/a:entry/apps:property[@name="from"]',ns).length, "Should have two 'from' properties")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@value="asf@boinkor.net abc@boinkor.net"]',ns).length, "Should have both addresses positively in one 'from' property")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@value="-asf@boinkor.net -abc@boinkor.net"]',ns).length, "Should have both addresses negated in one 'from' property")
  end

  describe "subject" do
    it "works with single subject" do
      fs = GmailBritta.filterset do
        filter {
          subject 'SPAM: '
          label 'important'
        }
      end

      filters = dom(fs)

      filter_text = filters.xpath('//apps:property[@name="subject"]', ns).first['value']
      assert_equal('SPAM: ', filter_text)
    end

    it "works with hash of subjects" do
      fs = GmailBritta.filterset do
        filter {
          subject :or => ['SPAM', 'HAM']
        }
      end

      filters = dom(fs)

      filter_text = filters.xpath('//apps:property[@name="subject"]', ns).first['value']
      assert_equal('SPAM OR HAM', filter_text)
    end
  end
end
