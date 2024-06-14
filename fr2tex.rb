#!/usr/bin/env ruby
# encoding: utf-8
#
# Copyright 2015 Charles Duan.
#
# This file is part of scholar2tex.
#
# fr2tex is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# fr2tex is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with scholar2tex.  If not, see <http://www.gnu.org/licenses/>.

require 'nokogiri'
require 'shellwords'
require 'json'
require 'time'
require 'open-uri'

class CaseParser

  def initialize(doc)
    @doc = doc
    @insection = false
    @inpart = false
    @text = process_elt(@doc)
  end
  attr_accessor :text

  def process_elt(elt)
    method = ('process_elt_' + elt.name.downcase).to_sym
    if respond_to?(method)
      send(method, elt)
    else
      warn("Unexpected element type #{elt.name}")
      process_text(elt)
    end
  end

  def process_text(elt)
    elt.children.map { |node|
      case node.type
      when Nokogiri::XML::Node::TEXT_NODE
        process_entities(node.content)
      when Nokogiri::XML::Node::ELEMENT_NODE
        process_elt(node)
      else
        warn("Unknown node type #{node.inspect}")
      end
    }.join
  end

  def process_entities(text)
    text.gsub(/[_&$%#]/, {
      '_' => "\\_",
      "&" => "\\&",
      "$" => "\\$",
      "%" => "\\%",
      "#" => "\\#",
    }).gsub("\"") { |q|
      @in_quote = !@in_quote; @in_quote ? "``" : "\\null''"
    }.gsub("§", "\\textsection{}").gsub("", "{}---{}").gsub(
      /(https?:\/\/[^ ]*)/, "\\url{\\1}"
    )
  end

  def process_elt_rule(elt)
    process_text(elt)
  end

  def process_elt_prorule(elt)
    process_text(elt)
  end

  def process_elt_effdate(elt)
    process_text(elt)
  end

  def process_elt_preamb(elt)
    process_text(elt)
  end
  def process_elt_agency(elt)
    "\\begin{center}\n\\bfseries\n" + process_text(elt) + "\\end{center}\n\n"
  end
  def process_elt_subagy(elt)
    "\\begin{center}\n\\bfseries\n" + process_text(elt) + "\\end{center}\n\n"
  end
  def process_elt_cfr(elt)
    "\\begin{center}\n\\bfseries\n" + process_text(elt) + "\\end{center}\n\n"
  end
  def process_elt_depdoc(elt)
    "\\begin{center}\n\\bfseries\n" + process_text(elt) + "\\end{center}\n\n"
  end
  def process_elt_rin(elt)
    "\\begin{center}\n\\bfseries\n" + process_text(elt) + "\\end{center}\n\n"
  end
  def process_elt_subject(elt)
    if @insection
      "\\textbf{#{process_text(elt)}}\n\n"
    else
      "\\begin{center}\n\\bfseries\n" + process_text(elt) + "\\end{center}\n\n"
    end
  end

  def process_elt_subpart(elt)
    @inpart = true
    text = process_text(elt)
    @inpart = false
    return text
  end

  def process_elt_part(elt)
    @inpart = true
    text = process_text(elt)
    @inpart = false
    return text
  end

  def process_elt_agy(elt)
    process_text(elt)
  end
  def process_elt_act(elt)
    process_text(elt)
  end
  def process_elt_sum(elt)
    process_text(elt)
  end
  def process_elt_dates(elt)
    process_text(elt)
  end
  def process_elt_add(elt)
    process_text(elt)
  end
  def process_elt_furinf(elt)
    process_text(elt)
  end
  def process_elt_suplinf(elt)
    process_text(elt)
  end
  def process_elt_lstsub(elt)
    process_text(elt)
  end
  def process_elt_auth(elt)
    process_text(elt)
  end
  def process_elt_sig(elt)
    "\n\n\\vskip.5\\baselineskip\n" + process_text(elt)
  end
  def process_elt_dated(elt)
    process_text(elt) + "\n\n"
  end
  def process_elt_name(elt)
    "\\textbf{" + process_text(elt) + "}\n\n"
  end
  def process_elt_title(elt)
    "\\emph{" + process_text(elt) + "}\n\n"
  end
  def process_elt_frdoc(elt)
    process_text(elt) + "\n\n"
  end
  def process_elt_bilcod(elt)
    process_text(elt) + "\n\n"
  end

  def process_elt_stars(elt)
    "\n\n\\centerline{*\\qquad*\\qquad*}\n\n"
  end

  def process_elt_regtext(elt)
    process_text(elt)
  end

  def process_elt_amdpar(elt)
    "\n\n\\amendmentpar " + process_text(elt) + "\n\n"
  end

  def process_elt_section(elt)
    @insection = true
    text = process_text(elt)
    @insection = false
    "\n\\begin{quotation}\n" + text + "\n\\end{quotation}\n"
  end

  def process_elt_sectno(elt)
    "\\noindent \\textbf{#{process_text(elt)}}\\quad "
  end

  def process_elt_hd(elt)
    if elt['SOURCE'] == 'HED'
      if @inpart
        "\\section{#{process_text(elt)}}\n"
      else
        "\\paragraph{#{process_text(elt)}}\n"
      end
    elsif elt['SOURCE'] == 'HD1'
      "\\section{#{process_text(elt)}}\n"
    elsif elt['SOURCE'] == 'HD2'
      "\\subsection{#{process_text(elt)}}\n"
    elsif elt['SOURCE'] == 'HD3'
      "\\subsubsection{#{process_text(elt)}}\n"
    else
      warn("Unknown HD source #{elt['SOURCE']}")
    end
  end

  def process_elt_extract(elt)
    process_text(elt)
  end

  def process_elt_fp(elt)
    text = process_text(elt)
    if text =~ /^(\w+)\. /
      number, text = $1, $'
      indent = case number
               when /^[IVX]+$/ then 0
               when /^[A-Z]$/ then 1
               when /^\d+$/ then 2
               when /^[a-z]$/ then 3
               else 4 end
      return "\\indentpar{#{indent}}{#{number}}{#{text}}\n\n"
    else
      return "#{text}\n\n"
    end
  end

  def process_elt_p(elt)
    process_text(elt) + "\n\n"
  end

  def process_elt_e(elt)
    case elt['T']
    when '02'
      "\\textbf{\\small #{process_text(elt)}}"
    when '03'
      "\\emph{#{process_text(elt)}}"
    when '04'
      "\\textbf{#{process_text(elt)}}"
    when '51', '52'
      "\\textsubscript{#{process_text(elt)}}"
    else
      warn("Unknown E type #{elt['T']}")
      process_text(elt)
    end
  end

  def process_elt_h2(elt)
    "\\section{#{process_text(elt)}}\n\n"
  end

  def process_elt_sup(elt)
    process_text(elt)
  end

  def process_elt_blockquote(elt)
    "\\begin{quote}\n#{process_text(elt)}\n\\end{quote}\n"
  end

  def process_elt_prtpage(elt)
    " \\pagenum{#{elt['P']}}\\ifhmode\\expandafter\\xspace\\fi "
  end

  def process_elt_su(elt)
    "\\textsuperscript{#{process_text(elt)}}"
  end

  def process_elt_ftref(elt)
    process_text(elt)
  end

  def process_elt_ftnt(elt)
    "\\insfootnote{#{process_text(elt).strip}}\n\n"
  end

  def process_elt_gpotable(elt)
    ttl = elt.at_xpath("./TTITLE")
    if ttl
      ttl = "\\begin{quote}\n" + \
        process_text(elt.at_xpath("./TTITLE")) + \
        "\\end{quote}\n"
    else
      ttl = ""
    end

    return "\\begin{table}\n#{ttl}\\begin{center}\n" + \
      "\\begin{tabular}{#{'l' * elt['COLS'].to_i}}\n" + \
      process_gpotable_headers(elt.xpath('./BOXHD/CHED')) + \
      process_gpotable_rows(elt.xpath('./ROW')) + \
      "\\end{tabular}\n\\end{center}\n\\end{table}\n"
  end

  def process_gpotable_headers(headers)
    # This method needs to deal with tables of multiple logical rows. The
    # apparent GPO format is to use the "H" attribute to indicate which row a
    # header is on, and for a given cell with "H" value $h$, the subsequent
    # $h+1$ columns are all under that cell.
    #
    # header_rows is an array with one element per logical row of the table.
    # Each row contains a number of elements corresponding to the cells in the
    # TeX table. Each cell is either nil (empty) or a two-element array, the
    # first element being the text of the cell and the second being the number
    # of columns the cell spans.
    header_rows = [ [] ]
    cur_col = 0
    headers.each do |ched|
      ched_h = ched['H'].to_i
      header_rows.push([ nil ] * cur_col) while header_rows.count < ched_h
      header_rows[ched_h - 1].pop if header_rows[ched_h - 1].last.nil?
      header_rows[ched_h - 1].push([ process_text(ched).strip, 0 ])
      if ched_h > 1
        (0 ... ched_h).each do |i|
          header_rows[i].last[1] += 1
        end
      end
      (ched_h ... header_rows.count).each do |i|
        header_rows[i].push(nil)
      end
      cur_col += 1
    end

    return "\\hline\n" + header_rows.map { |row|
      row.map { |val|
        if val.nil? then ""
        elsif val[1] <= 1 then "\\textbf{#{val[0]}}"
        else "\\multicolumn{#{val[1]}}{l}{\\textbf{#{val[0]}}}"
        end
      }.join("&") + "\\\\\n"
    }.join("") + "\\hline\n"
  end

  def process_gpotable_rows(rows)
    return rows.map { |row|
      row.xpath("./ENT").map { |ent| process_text(ent) }.join("&") + "\\\\\n"
    }.join("") + "\\hline\n"
  end

  #
  # This appears to be an element for a hard line break in a table cell.
  # Currently I don't have a good way of dealing with multi-line texts in cells.
  #
  def process_elt_li(elt)
    return process_text(elt)
  end

  def process_elt_fr(elt)
    text = process_text(elt)
    if text =~ /\//
      "$\\frac{#$`}{#$'}$"
    else
      text
    end
  end

end

json = nil
begin
  json = URI.open(ARGV[0]) do |io| JSON.parse(io.read) end
rescue
  STDERR.puts "You must provide the JSON link for the regulation"
  exit 1
end

STDERR.puts "URL is #{json["full_text_xml_url"]}"

date = Time.parse(json['publication_date']).strftime("%B %-d, %Y")
citation = "#{json['volume']} Fed. Reg. #{json['start_page']}"
xml = URI.open(json["full_text_xml_url"])
doc = Nokogiri::XML(xml)
cp = CaseParser.new(doc)

puts "\\documentclass[twoside,11pt]{article}"
puts "\\usepackage{fixltx2e}"
puts "\\usepackage{casemacs}"
puts ""
puts "\\citation{#{citation} (#{date})}"
puts "\\caption{DEF}"
puts "\\shortcaption{#{json['docket_ids'].join(", ")}}"
puts "\\docket{JKL}"
puts "\\court{MNO}"
puts ""
puts "\\begin{document}"
puts "\\thispagestyle{empty}"
puts "\\begin{center}\\bfseries #{json['type']}\\\\#{citation}\\\\#{date}"
puts "\\end{center}"
puts cp.text
puts "\\end{document}"
