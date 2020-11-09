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

  def process_elt_prorule(elt)
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
    if elt['T'] == '03'
      "\\emph{#{process_text(elt)}}"
    elsif elt['T'] == '04'
      "\\textbf{#{process_text(elt)}}"
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
    warn("GPOTABLE not supported")
    "\\textbf{Tables not yet supported}\n\n"
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
json = JSON.parse(`curl #{ARGV[0].shellescape}`)

STDERR.puts "URL is #{json["full_text_xml_url"]}"

date = Time.parse(json['publication_date']).strftime("%B %-d, %Y")
citation = "#{json['volume']} Fed. Reg. #{json['start_page']}"
xml = `curl #{json["full_text_xml_url"].shellescape}`
doc = Nokogiri::XML(xml)
cp = CaseParser.new(doc)

puts "\\documentclass[twoside,11pt]{article}"
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
