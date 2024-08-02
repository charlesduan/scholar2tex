#!/usr/bin/env ruby
# encoding: utf-8
#
# Copyright 2014 Charles Duan.
#
# This file is part of scholar2tex.
#
# scholar2tex is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# scholar2tex is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with scholar2tex.  If not, see <http://www.gnu.org/licenses/>.

require 'nokogiri'
require 'open-uri'

class CaseParser

  def initialize(doc)
    @doc = doc
    @opinion = doc.at_css('#gs_opinion')
    parse_footnotes
    parse_opinion
  end

  attr_accessor :footnotes

  def parse_footnotes
    @footnotes = {}
    last_footnote = ""
    elt = @opinion.css('small').last
    return unless elt
    elt = elt.next_element
    elt.previous_element.unlink
    while (elt)
      first_elt = elt.elements.first
      if first_elt && first_elt.name == 'a' && first_elt['href']
        if first_elt['href'] =~ /^#r\[(.+)\]$/
          fnref = $1
          first_elt.unlink
          last_footnote = @footnotes[fnref] = ""
        end
      end
      last_footnote << process_elt(elt) if elt['id'] != 'gs_dont_print'
      if elt.next_element.nil?
        elt.unlink
        elt = nil
      else
        elt = elt.next_element
        elt.previous_element.unlink
      end
    end
  end

  def text
    @text.join
  end

  def header
    @caption.join("\n\\vskip 6pt\n")
  end

  def parse_opinion
    in_caption = true
    @caption, @text = [], []
    @opinion.elements.each do |elt|
      if in_caption && elt.name == 'center'
        @caption.push(process_elt(elt))
      else
        in_caption = false
        unless elt['id'] == 'gs_dont_print'
          @text.push(process_elt(elt))
        end
      end
    end
  end

  def process_elt(elt)
    method = ('process_elt_' + elt.name).to_sym
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
    }).gsub(/(.)?\"(.)?/) { |q|
      @in_quote = !@in_quote
      quote = @in_quote ? "``" : "''"
      if ($1 == '`' || $1 == '\'') then quote = "\\,#{quote}" end
      if ($2 == '`' || $2 == '\'') then quote = "#{quote}\\," end
      "#$1#{quote}#$2"
    }.gsub(/(§+)(.)/) { |match|
      suffix = case $2
               when " " then "~"
               when "\w" then " #$2"
               else $2
               end
      ("\\S" * $1.length) + suffix
    }.gsub(
      "", "---"
    ).gsub(
      /(https?:\/\/[^ ]*)/, "\\url{\\1}"
    )
  end

  JUDGE_RE = /Justice|Judge|[^abd-z]+, (?:[CJ.]*J\.|(?:\w+ )?Judges?)/
  OPINING_RE = /concurring|dissenting|delivered (?:the|an) opinion/

  def process_elt_p(elt)
    @in_quote = false
    text = process_text(elt)

    # Identifies concurrence and dissent markers
    if text =~ /^#{JUDGE_RE}.*#{OPINING_RE}/
      text = "\\vskip\\baselineskip\n\n\\textbf{#{text}}"
    end

    return text + "\n\n"
  end

  def process_elt_i(elt)
    t = process_text(elt)
    suffix = ""
    if t =~ /,?\s*\z/ then t, suffix, = $`, $& end
    "\\textit{#{t}}#{suffix}"
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

  def process_elt_a(elt)
    if elt['class'] == 'gsl_pagenum'
    elsif elt['class'] == 'gsl_pagenum2'
      "\\pagenum{#{process_text(elt).sub(/^\*/, '')}}"
    elsif elt['href']
      if elt['href'] =~ /^#\[(.*)\]$/
        fnref = $1
        if @footnotes[fnref]
          "\\footnote[#{fnref}]{#{@footnotes[fnref].strip}}"
        else
          warn("Missing footnote #{fnref}")
          ""
        end
      elsif elt['href'] =~ /^\/scholar(_case)?\?/
        process_text(elt)
      else
        warn("Unknown link: #{elt['href']}")
        process_text(elt)
      end
    else
      warn("Unexpected anchor: #{elt.to_html}--#{elt['class']}")
      process_text(elt)
    end
  end

  def process_elt_center(elt)
    "\\begin{centering}\n#{process_text(elt)}\\par\n\\end{centering}\n"
  end

  def process_elt_b(elt)
    if elt['style'] == 'color:black;background-color:#ffc'
      process_text(elt)
    else
      t = process_text(elt)
      suffix = ""
      if t =~ /,?\s*\z/ then t, suffix, = $`, $& end
      "\\textbf{#{t}}#{suffix}"
    end
  end

  def process_elt_br(elt)
    "\\penalty-10000\\relax"
  end


  def process_elt_h3(elt)
    "{\\large\\bfseries #{process_text(elt)}\\par}"
  end

  def citation
    process_text(@opinion.at_css('center b'))
  end

  def caption
    res = process_text(@opinion.at_css('h3#gsl_case_name'))
    res.gsub("\r", "")
  end

  def shortcaption
    if caption =~ /\s*v\.\s*/m
      topside, bottomside = $`, $'
      [ topside, bottomside ].map { |x|
        x = x.strip.sub(/,.*/, "")
        x = x.sub(/et al\.?$/i, "")
        select_words(x.split(/\s+/))
      }.join(" v.~")
    else
      warn("Cannot parse caption: #{caption}")
      caption.gsub("\n", " ")
    end
  end

  #
  # Chooses words from a party name to be a short caption. The basic rule is
  # that (1) we assume that only fully-capitalized words in a party name matter
  # (words with lowercase letters are usually people's first names or
  # conjunctions between parties), and (2) the first two words of a corporate
  # party's name are sufficient, so long as the second word is permissible as an
  # ending of a name (so we don't get "Securities and" as a party name).
  #
  def select_words(words)
    found = nil
    words.each do |word|

      # Skip single-letter abbreviations and words that contain lowercase
      # letters
      next if (word =~ /^.\.$/ or word =~ /[a-z]/)

      if found

        # If we've already found the first word, then add this word to the short
        # caption string. If the present word is a short word, then we cannot
        # end the caption with this word so we continue. Otherwise, we terminate
        # the word-finding loop.
        found += " #{word}"
        break unless SHORT_WORDS.include?(word.downcase)
      else

        # Always include the first all-caps word in the short caption.
        found = word
      end
    end

    # Adjust capitalization and return the found words.
    return decapitalize_words(found) if found

    # In case of failure (no words found), return the whole string with
    # capitalization adjusted.
    return decapitalize_words(words.join(" "))
  end

  SHORT_WORDS = %w(of in a the for to and \&)

  def decapitalize_words(words)
    if words =~ /\.$/
      nodot_words = words.sub(/\.$/, "")
      return $1 if (text =~ /(#{Regexp::escape(nodot_words)})[^.]/i)
    end
    return ($&) if (text =~ /#{Regexp::escape(words)}/i)
    return words.split(/\s+/).map { |x| x.capitalize }.join(" ")
  end


  def docket
    process_text(@opinion.css('center')[2]).strip
  end

  def court
    process_text(@opinion.css('center')[3]).strip
  end

end

if ARGV[0] == '-p'
  ARGV[0] = `pbpaste`
end

open(ARGV[0]) do |f|
  doc = Nokogiri::HTML(f)
  cp = CaseParser.new(doc)

  puts "\\documentclass[twoside,11pt]{article}"
  puts "\\usepackage{casemacs}"
  puts ""
  puts "\\citation{#{cp.citation}}"
  puts "\\caption{#{cp.caption.gsub("\n", "\\\\\\\\\n")}}"
  puts "\\shortcaption{#{cp.shortcaption}}"
  puts "\\docket{#{cp.docket}}"
  puts "\\court{#{cp.court}}"
  puts ""
  puts "\\begin{document}"
  puts "\\thispagestyle{empty}"
  puts cp.header
  puts "\\vskip 1\\baselineskip plus 1\\baselineskip"
  puts cp.text
  puts "\\end{document}"
end
