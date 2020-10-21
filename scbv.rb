#!/usr/bin/ruby

require 'nokogiri'
require 'open-uri'
require 'tempfile'

def justia_url(vol)
  "https://supreme.justia.com/justia-ussc-sitemap.#{vol}.xml"
end

def find_pages(vol, page)
  doc = Nokogiri::XML(open(justia_url(vol)))
  pages = {}
  doc.css('loc').each do |node|
    text = node.content
    if text =~ /cases\/federal\/us\/#{vol}\/(\d+)\//
      pages[$1.to_i] = true
    end
  end
  first_page = pages.select { |x| x <= page }.max
  last_page = pages.select { |x| x > page }.min
  return [ first_page, last_page ]
end

class NoHeadError < StandardError
end

class BoundVolume

  def initialize(vol, page)
    @vol = vol
    @page = page
  end

  def download_volume
    if File.exist?("#{@vol}bv.pdf")
      @file = File.new("#{@vol}bv.pdf", 'r')
      return @file
    end
    url = "https://www.supremecourt.gov/opinions/boundvolumes/#{@vol}bv.pdf"
    @file = Tempfile.new([ "vol", ".pdf" ])
    puts "Downloading #{url}"
    open(url) do |f|
      loop do
        str = f.read(4096)
        break unless str
        @file.write(str)
      end
    end
    @file.close
    return @file
  end

  # Returns the header value and the page number on this page.
  def parse_raw_page(page)
    IO.popen([
      'pdftotext', '-layout', '-f', page.to_s, '-l', page.to_s, @file.path, '-'
    ]) do |io|
      io.each_line do |line|
        case line
        when /PAGES OPINPGT/  then next
        when /PAGES PGT: OPIN/  then next
        when /^\s*$/          then next
        when /^(\d+)\s+(\S.*)$/
          return [ $2, $1.to_i ]
        when /^\s*(\S.*\S)\s+(\d+)$/
          return [ $1, $2.to_i ]
        when /Reporter's Note/
          return [ $&, 1000 ]
        when /ORDERS FOR/
          return [ "", 1001 ]
        else
          raise NoHeadError, "Could not find header on page #{page}: #{line}"
        end
      end
    end
    raise NoHeadError, "Reached EOF without finding header line"
  end

  def offset
    return @offset if @offset
    text, page = parse_raw_page(300)
    @offset = 300 - page
    return @offset
  end

  def parse_page(page)
    return parse_raw_page(page + offset)
  end

  def get_page_headers
    if @page.even?
      @odd_head, @even_head = parse_page(@page + 1)[0], parse_page(@page + 2)[0]
    else
      @even_head, @odd_head = parse_page(@page + 1)[0], parse_page(@page + 2)[0]
    end
    return [ @even_head, @odd_head ]
  end

  def find_last_page
    cur_page = @page + 2
    increment = 64

    # Associates page numbers with whether they have been tested to be beyond
    # the desired opinion.
    too_far = {}

    loop do
      cur_page += increment
      if too_far[cur_page].nil? # If the page has not yet been tested
        begin
          yield(cur_page)
          too_far[cur_page] = test_page(cur_page)
        rescue NoHeadError
          # In some cases the Court will insert appendices or other material
          # that don't follow the normal headers. In such cases, skip to the
          # next page and test that one instead.
          cur_page += 1
          retry
        end
      end

      if too_far[cur_page]
        cur_page -= increment
        if increment == 1
          @last_page = cur_page
          return @last_page
        else
          increment /= 2
        end
      end

    end
  end

  # Tests if a page is outside the desired opinion, by seeing if its header
  # matches the header for the desired opinion.
  def test_page(cur_page)
    exp_head = cur_page.even? ? @even_head : @odd_head
    pp = parse_page(cur_page)
    return (pp[0] != exp_head)
  end

  def make_pdf(outfile)
    system(
      'cpdf', '-i', @file.path,
      "#{@page + @offset}-#{@last_page + @offset}", '-o', outfile
    )
  end
end


#
# MAIN PROGRAM
#

volume, page = ARGV.first.to_i, ARGV.last.to_i

raise "Invalid volume" unless volume >= 502
raise "Invalid page" unless page > 0

bv = BoundVolume.new(volume, page)
bv.download_volume
puts "Downloaded file."

even, odd = bv.get_page_headers
puts "#{even} -- #{odd}"

bv.find_last_page do |cur_page|
  print "Testing #{cur_page}\r"
end
puts ""

bv.make_pdf("texput.pdf")

if page.even?
  system('booklet.rb', '-b', '2.2,2.2,6.4,9.4', '-e', 'texput.pdf')
else
  system('booklet.rb', '-b', '2.2,2.2,6.4,9.4', 'texput.pdf')
end

