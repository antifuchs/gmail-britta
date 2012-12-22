require 'bundler/setup'
require 'minitest/unit'
require 'nokogiri'
require 'minitest/autorun'

require 'gmail-britta'

describe GmailBritta do
  def simple_filterset
    fs = GmailBritta.filterset() do
      filter {
        has %w{to:asf@boinkor.net}
        label 'ohai'
      }.archive_unless_directed
    end
  end

  def dom(filterset)
    text = simple_filterset.generate
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
    filters = simple_filterset.generate
    assert(filters, "Should generate something")
    assert(filters.is_a?(String), "Generated filters should be a string")
  end

  it "generates xml" do
    filters = dom(simple_filterset)

    assert_equal(2, filters.xpath('/a:feed/a:entry',ns).length, "Should have exactly one filter entry")
    assert_equal(5, filters.xpath('/a:feed/a:entry/apps:property',ns).length, "Should have two properties")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="label"]',ns).length, "Should have exactly one 'label' property")
    assert_equal(1, filters.xpath('/a:feed/a:entry/apps:property[@name="shouldArchive"]',ns).length, "Should have exactly one 'shouldArchive' property")
    assert_equal(2, filters.xpath('/a:feed/a:entry/apps:property[@name="hasTheWord"]',ns).length, "Should have exactly one 'has' property")
  end


end
