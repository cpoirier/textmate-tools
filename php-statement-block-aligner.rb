#!/usr/bin/env ruby
# =============================================================================================
# PHP statement block aligner
#
# This script can be used as a command for TextMate to horizontally align the major structures 
# within a block of similar PHP statements. When using it with TextMate, set the command input 
# to "Selected Text" or "Document", and the output to "Replace Selected Text". Map it to a key 
# equivalent, and any time you want to tidy up a block, either select it, or put your cursor 
# within or just below it, and voila.
#
# The script is loosely based on my assignment block aligner that I wrote back in 2006. This 
# version attempts to align along more structures, and is specifically designed for use with 
# PHP, as it has to know a lot about the language in order to work. Versions for other 
# languages may follow.
#
# [Website]   http://github.com/cpoirier/textmate-tools/php-statement-block-aligner.rb
# [Copyright] Copyright 2012 Chris Poirier
# [License]   Licensed under the Apache License, Version 2.0 (the "License");
#             you may not use this file except in compliance with the License.
#             You may obtain a copy of the License at
#             
#                 http://www.apache.org/licenses/LICENSE-2.0
#             
#             Unless required by applicable law or agreed to in writing, software
#             distributed under the License is distributed on an "AS IS" BASIS,
#             WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#             See the License for the specific language governing permissions and
#             limitations under the License.
# =============================================================================================

LOG_CONTROL = {:parse => false, :tree => true}
LOG_STREAM  = $stderr




# =============================================================================================
# BASIC COMPONENTS

class AlignmentTerminated < Exception ; end    # Raised when we just need to bail out.
class ParseFailed         < Exception ; end    # Raised when parsing fails.

class Product
   def initialize( type )
      @type = type
   end
   
   def is?( type )
      @type == type
   end
   
   attr_reader :type
end

class Object
   def instance_class()
      class << self ; self ; end
   end
   
   def caller_method(level = 2)
      name = caller(level).first.sub(/^.*in ./, "").sub(/.$/, "").intern
      instance_class.instance_method(name) 
   end
end

class String
   def leading_spaces()
      self =~ /^( +)/ ? $1.length : 0
   end
end

def log( type = :basic )
   if LOG_CONTROL[type] then
      yield(LOG_STREAM)
   end
end




# =============================================================================================
# TOKENIZER


class Token < Product
   def initialize( type, string )
      super(type)
      @string = string
   end
   
   def map_via( type )
      Type[type].map(@type)
   end
   
   def to_s()
      @string
   end
   
   def dump( indent = "", stream = $stdout )
      stream.puts "#{indent}#{@type} '#{@string}'"
   end
   
   attr_reader :string
end


class PHPTokenizer
   
   def initialize( line, number )
      @line   = line
      @number = number
      @pos    = 0
   end
   
   attr_reader :line, :pos, :number
   
   def mark()
      [@pos]
   end
   
   def restore( mark )
      @pos = mark.first
   end
   
   
   @@whitespace    = /^[ \t\r\n]+/
   @@numbers       = /^((\d+(?:\.\d*)?)|(\.\d+))/
   @@words         = /^((\$?[a-zA-Z_]+))/
   @@in_equalities = /^(==(=?)|!=(=*))/ 
   @@comparators   = /^>(=?)|<(=?)|<>/
   @@assigners     = /^([-+*\/%.^]|<<|>>)?=/
   @@scopers       = /^(->|::)/
   @@structural    = /^([(){}\[\]?:,@;]|=>)/
   @@operators     = /^(\+(\+?)|-(-?)|!|~|\^|\*|\/|%|\.|\|(\|?))|>>|<<|&(&?)/
      
   def next_token()
      token     = nil
      remaining = @line[@pos..-1]
      
      if @pos < @line.length then
         case remaining
         when @@whitespace   ; token = Token.new(:whitespace      , consume($&.length)    )
         when @@numbers      ; token = Token.new(:number          , consume($&.length)    )
         when @@words                                             
            case string = $&                                      
            when "or"        ; token = Token.new(:keyword_or      , consume(string.length))
            when "and"       ; token = Token.new(:keyword_and     , consume(string.length))
            when "xor"       ; token = Token.new(:keyword_xor     , consume(string.length))
            when "new"       ; token = Token.new(:keyword_new     , consume(string.length))
            when "clone"     ; token = Token.new(:keyword_clone   , consume(string.length))
            when "if"        ; token = Token.new(:keyword_if      , consume(string.length))
            when "while"     ; token = Token.new(:keyword_while   , consume(string.length))
            else             ; token = Token.new(:word            , consume(string.length))
            end                                                   
         when @@in_equalities; token = Token.new(:in_equality     , consume($&.length)    )                                     
         when @@comparators  ; token = Token.new(:comparator      , consume($&.length)    )
         when @@assigners    ; token = Token.new(:assigner        , consume($&.length)    )
         when @@scopers      ; token = Token.new(:scoper          , consume($&.length)    )
         when @@structural                                          
            case symbol = $&                                        
            when "?"         ; token = Token.new(:question        , consume(1)            )
            when ":"         ; token = Token.new(:colon           , consume(1)            )
            when ","         ; token = Token.new(:comma           , consume(1)            )
            when "@"         ; token = Token.new(:at              , consume(1)            )
            when ";"         ; token = Token.new(:semicolon       , consume(1)            )
            when "=>"        ; token = Token.new(:pairer          , consume(2)            )
            when "("         ; token = Token.new(:open_paren      , consume(1)            )
            when ")"         ; token = Token.new(:close_paren     , consume(1)            )
            when "["         ; token = Token.new(:open_bracket    , consume(1)            )
            when "]"         ; token = Token.new(:close_bracket   , consume(1)            )
            when "{"         ; token = Token.new(:open_brace      , consume(1)            )
            when "}"         ; token = Token.new(:close_brace     , consume(1)            )
            end                                                     
         when @@operators                                           
            case operator = $&                                      
            when "||"        ; token = Token.new(:double_pipe     , consume($&.length)    )
            when "&&"        ; token = Token.new(:double_ampersand, consume($&.length)    )
            when "<<"        ; token = Token.new(:double_left     , consume($&.length)    )
            when ">>"        ; token = Token.new(:double_right    , consume($&.length)    )
            when "|"         ; token = Token.new(:pipe            , consume($&.length)    )
            when "^"         ; token = Token.new(:caret           , consume($&.length)    )
            when "&"         ; token = Token.new(:ampersand       , consume($&.length)    )
            when "++"        ; token = Token.new(:plusplus        , consume($&.length)    )
            when "--"        ; token = Token.new(:minusminus      , consume($&.length)    )
            when "+"         ; token = Token.new(:plus            , consume($&.length)    )
            when "-"         ; token = Token.new(:minus           , consume($&.length)    )
            when "."         ; token = Token.new(:dot             , consume($&.length)    )
            when "*"         ; token = Token.new(:star            , consume($&.length)    )
            when "/"         ; token = Token.new(:slash           , consume($&.length)    )
            when "%"         ; token = Token.new(:percent         , consume($&.length)    )
            when "!"         ; token = Token.new(:exclamation     , consume($&.length)    )
            when "~"         ; token = Token.new(:tilde           , consume($&.length)    )
            end
         when /^'/
            characters = [consume(1)]
            while @pos < @line.length
               case @line[@pos]
               when '\\'
                  characters << consume(2)
               when '\''
                  characters << consume(1)
                  break
               else
                  characters << consume(1)
               end
            end
            token = Token.new(:string, characters.join())
         when /^"/
            characters = [consume(1)]
            while @pos < @line.length
               case @line[@pos]
               when '\\'
                  characters << consume(2)
               when '"'
                  characters << consume(1)
                  break
               else
                  characters << consume(1)
               end
            end
            token = Token.new(:string, characters.join())
         else
            raise AlignmentTerminated.new("cannot tokenize: #{@line[@pos]}")
         end
      end
      
      token
   end
   
   
   def consume( count )
      string = @line[@pos, count]
      @pos += count
      string
   end
end





# =============================================================================================
# PARSER


class Expression < Product
   def initialize( type, elements = {} )
      super(type)
      @elements = elements
   end
   
   attr_reader :elements
   
   def dump( indent = "", stream = $stdout, inline = false )
      stream.print indent unless inline
      stream.puts "Expression #{@type}:"
      
      width = @elements.keys.collect{|k| k.to_s.length}.max()
      @elements.each do |n, e| 
         child_indent = indent + "   "
         stream.print "#{child_indent}#{n.to_s.ljust(width)}: "
         
         case e
         when Expression 
            e.dump(child_indent + (" " * width) + ": ", stream, true)
         when Token            
            stream.puts "#{e.type} '#{e.string}'"
         when NilClass
            stream.puts "nil"
         else
            raise "BUG: found unexpected expression element of class #{e.class.name}"
         end
      end
      
      stream.puts indent if inline
   end
end


class PHPLineParser
   
   def self.parse( line, number = 0 )
      result = nil
      
      self.new(PHPTokenizer.new(line, number)).tap do |parser|
         parser.instance_eval do
            parse_statements().tap do |tree|
               if result = tree then
                  log(:tree) do |stream|
                     stream.puts ""
                     stream.puts "   #{line}"
                     tree.dump("   ", stream)
                  end
               end
            end
         end
      end
      
      result
   end
   
   

protected

   def initialize( tokenizer )
      @tokenizer = tokenizer
      @lookahead = []
      @trace     = []
   end
   
   def la( distance = 1, return_token = false )
      while @lookahead.length < distance && token = @tokenizer.next_token()
         @lookahead << token unless token.is?(:whitespace)
      end

      return nil if @lookahead.length < distance
      token = @lookahead[distance - 1]
      return_token ? token : token.type
   end
   
   def la_is?( *types )
      types.each_index do |index|
         return false unless la(index + 1) == types[index]
      end
      
      return true
   end
   
   def la_is_one_of?( *types )
      types.each do |type|
         return true if la() == type
      end
      
      return false
   end
   
   def consume( type = nil, value = nil )
      log(:parse) do |stream| 
         stream.puts "   ==> attempting to consume " + (value ? "(#{type} '#{value}')" : "#{type}")
      end

      (la() && (!type || la() == type) && (!value || la(1, true).string == value)) or fail()      
      @lookahead.shift.tap do |consumed|
         log(:parse) do |stream| 
            stream.puts "   ==> consumed (#{consumed.type} #{consumed})"
         end
      end
   end
   
   def consume_one_of( *types )
      types.each do |type|
         return @lookahead.shift if la() == type 
      end
      
      fail()
   end
   
   def fail()
      raise ParseFailed.new()
   end
      
   def fail_unless( expression )
      fail() unless expression
      expression
   end
   
   def attempt_optional()
      value = nil
      begin
         value = yield
      rescue ParseFailed
      end
      value
   end
   
   def attempt()
      mark  = [@lookahead.clone, @tokenizer.mark(), @trace]
      value = nil
      begin
         value = yield
      rescue ParseFailed
         @lookahead = mark[0]
         @tokenizer.restore(mark[1])
         @trace     = mark[2]
         
         log(:parse) do |stream|
            stream.puts "   ==> parsing failed; restoring to #{@trace} with (#{la()} '#{la(1, true)}'), (#{la(2)} '#{la(2, true)}')"
         end
      end
      value
   end
   
   def parse_binary_operator_expression( type, operators, lhs_parser, rhs_parser = :parse_at_expression )
      operators.is_a?(Array) or operators = [operators]
      rhs_parser or rhs_parser = caller_method.name
      
      if expression = send(lhs_parser) then
         while la_is_one_of?(*operators)
            expression = Expression.new(type, :lhs => expression, :op => consume_one_of(*operators), :rhs => fail_unless(send(rhs_parser)))
         end
      end
      
      expression
   end
   
   def trace()
      @trace = caller_method().name
      log(:parse) do |stream|
         stream.puts "   #{@trace}() with (#{la(1)} '#{la(1, true)}'), (#{la(2)} '#{la(2, true)}')"
      end
   end
   
protected
   
   def parse_statements( terminator = nil )
      trace()
      if la() && (!terminator || la() != terminator) then
         first = fail_unless(parse_statement())
         la() ? Expression.new(:statement_sequence, :first => first, :rest => parse_statements()) : first
      else
         nil
      end
   end
   
   
   def parse_statement()
      trace()
      attempt{parse_if_statement()} || attempt{parse_while_statement()} || Expression.new(:statement, :body => fail_unless(parse_sequence_or_expression()), :terminator => consume(:semicolon))
   end
   
   
   def parse_block()
      trace()
      if la_is?(:open_brace) then
         Expression.new(:statement_block, :open_brace => consume(:open_brace), :body => parse_statements(:close_brace), :close_brace => consume(:close_brace))
      else
         parse_statement()
      end
   end
   
   
   def parse_if_statement()
      trace()
      Expression.new(:if_statement, :keyword => consume(:keyword_if), :open_paren => consume(:open_paren), :condition => fail_unless(parse_expression()), :close_paren => consume(:close_paren), :body => parse_block());
   end
   
   
   def parse_while_statement()
      trace()
      Expression.new(:while_statement, :keyword => consume(:keyword_while), :open_paren => consume(:open_paren), :condition => fail_unless(parse_expression()), :close_paren => consume(:close_paren), :body => parse_block());
   end
   
   
   def parse_expression()
      trace()
      parse_parenthesized_expression()
   end
   
   
   def parse_parenthesized_expression()
      trace()
      if la() == :open_paren then
         Expression(:parenthesized_expression, :open_paren => consume(:open_paren), :body => parse_expression(), :close_paren => consume(:close_paren))
      else
         parse_sequence_or_expression()
      end
   end
   
   def parse_sequence_or_expression()
      trace()
      parse_binary_operator_expression(:sequence_or, :keyword_or, :parse_sequence_xor_expression)
   end
   
   
   def parse_sequence_xor_expression()
      trace()
      parse_binary_operator_expression(:sequence_xor, :keyword_xor, :parse_sequence_and_expression)
   end
   
   
   def parse_sequence_and_expression()
      trace()
      parse_binary_operator_expression(:sequence_and, :keyword_and, :parse_assignment_expression)
   end
   
   
   def parse_assignment_expression()
      trace()
      expression = attempt do
         Expression.new(:assignment, :lhs => fail_unless(parse_lh_expression()), :op => consume(:assigner), :rhs => fail_unless(parse_assignment_expression()))
      end
      
      expression || parse_ternary_expression()
   end
   
   
   def parse_ternary_expression()
      trace()
      expression = attempt do
         Expression.new(:ternary_expression, :condition => fail_unless(parse_logical_or_expression()), :question => consume(:question), :true_branch => fail_unless(parse_ternary_expression()), :colon => consume(:colon), :false_branch => fail_unless(parse_ternary_expression()))
      end
      
      expression || parse_logical_or_expression()
   end
      
      
   def parse_logical_or_expression()      
      trace()
      parse_binary_operator_expression(:logical_or, :double_pipe, :parse_logical_and_expression)
   end
   
   
   def parse_logical_and_expression()
      trace()
      parse_binary_operator_expression(:logical_and, :double_ampersand, :parse_bitwise_or_expression)
   end
   
   
   def parse_bitwise_or_expression()
      trace()
      parse_binary_operator_expression(:bitwise_or, :pipe, :parse_bitwise_complement_expression)
   end
   
   def parse_bitwise_complement_expression()
      trace()
      parse_binary_operator_expression(:bitwise_complement, :caret, :parse_bitwise_and_expression)
   end
   
   def parse_bitwise_and_expression()
      trace()
      parse_binary_operator_expression(:bitwise_and, :ampersand, :parse_equality_expression)
   end
   
   def parse_equality_expression()
      trace()
      parse_binary_operator_expression(:equality_test, :in_equality, :parse_comparison_expression)
   end
   
   def parse_comparison_expression()
      trace()
      parse_binary_operator_expression(:comparison_test, :comparator, :parse_bitwise_shift_expression)
   end
   
   def parse_bitwise_shift_expression()
      trace()
      parse_binary_operator_expression(:bitwise_shift, [:double_left, :double_right], :parse_addition_expression)
   end
   
   def parse_addition_expression()
      trace()
      parse_binary_operator_expression(:addition, [:plus, :minus, :dot], :parse_multiplication_expression)
   end
   
   def parse_multiplication_expression()
      trace()
      parse_binary_operator_expression(:multiplication, [:star, :slash, :percent], :parse_logical_not_expression)
   end
   
   def parse_logical_not_expression()
      trace()
      la() == :exclamation ? Expression.new(:logical_not, :op => consume(:exclamation), :expression => fail_unless(parse_logical_not())) : parse_at_expression()
   end
   
   def parse_at_expression()
      trace()
      la() == :at ? Expression.new(:error_suppression, :op => consume(:at), :expression => fail_unless(parse_at_expression())) : parse_unary_expression()
   end
   
   def parse_unary_expression()
      trace()
      expression = case la()
      when :tilde
         Expression.new(:bitwise_complement, :op => consume(:tilde), :expression => fail_unless(parse_at_expression()))
      when :minus
         Expression.new(:negation, :op => consume(:minus), :expression => fail_unless(parse_at_expression()))
      when :open_paren
         if la(2) == :word && la(3) == :close_paren && %w(int float string array object bool).member?(la(2, true).string) then
            Expression.new(:type_cast, :open_paren => consume(:open_paren), :type => consume(:word), :close_paren => consume(:close_paren), :expression => fail_unless(parse_unary_expression()))
         end
      end
      
      expression || parse_prefix_expression()
   end
   
   def parse_prefix_expression()
      trace()
      la_is_one_of?(:plusplus, :minusminus) ? Expression.new(:prefix, :op => consume(), :expression => parse_variable_expression()) : parse_postfix_expression()
   end
   
   def parse_postfix_expression()
      trace()
      expression = parse_function_call_expression()
      la_is_one_of?(:plusplus, :minusminus) ? Expression.new(:postfix, :expression => expression, :op => consume()) : expression
   end
   
   def parse_function_call_expression()
      expression = parse_object_expression()
      if la() == :open_paren then
         expression = Expression.new(:function_call, :name => expression, :open_paren => consume(:open_paren), :parameters => attempt_optional{parse_comma_list()}, :close_paren => consume(:close_paren))
      end
      expression
   end
      
   def parse_object_expression()
      expression = parse_simple_expression()
      if la() == :scoper then
         expression = Expression.new(:object_expression, :expression => expression, :scoper => consume(:scoper), :offset => fail_unless(parse_object_expression()))
      end
      expression
   end
      
   def parse_simple_expression()
      case la(1)
      when :word
         expression = consume(:word)
         while la() == :open_bracket
            expression = Expression.new(:array_expression, :array => expression, :open_bracket => consume(:open_bracket), :index => fail_unless(parse_expression()), :close_bracket => consume(:close_bracket))
         end
         expression
      when :string
         consume(:string)
      when :number
         consume(:number);
      else
         fail()
      end
   end
         
   def parse_comma_list()
      trace()
      lhs = parse_expression()
      la() == :comma ? Expression.new(:comma_list, :lhs => lhs, :comma => consume(:comma), :rhs => fail_unless(parse_comma_list())) : lhs
   end


   def parse_lh_expression()
      trace()
      if la() == :at then
         Expression.new(:error_suppression, :op => consume(:at), :expression => fail_unless(parse_lh_expression()))
      else
         (attempt{parse_lh_list_expression()} || parse_object_expression())
      end
   end

   
   def parse_lh_list_expression()
      trace()
      Expression.new(:list_receiver, :keyword => consume(:word, "list"), :open_paren => consume(:open_paren), :targets => fail_unless(parse_comma_list()), :close_paren => consume(:close_paren))
   end
   
      
end




# =============================================================================================
# THE COLUMNATOR

class Columnator
   def columnate( trees )
      columnate_sequence_expression(trees)
   end
   
   # def columnate_sequence_expression( trees )
   #    columns = {:lhs => [], :operator => [], : rhs => []}
   #    trees.each do |tree|
   #       if tree.type == :sequence_or || tree.type == :sequence_and || tree.type == :sequence_xor then
   #          columns[:lhs] << 
   #       else
   #       end
   #    end
   # end
   # 
   
   
protected
   def initialize( trees )
      @trees = trees
   end
   
   def layout_sequence()
      
   end
   
end






# =============================================================================================
# PROCESS THE INPUT


lines        = STDIN.readlines()
block_top    = 0
block_bottom = lines.length - 1

#
# If called from TextMate, figure out what lines to process.

if ENV.member?("TM_LINE_NUMBER") then
   selected_text = ENV.member?("TM_SELECTED_TEXT")

   #
   # If called on a selection, every statement is in the block.  If called on the document, we 
   # start on the current line and look and down for the start and end of the block.

   if selected_text then
      block_top    = 1
      block_bottom = lines.length
   else
   
      start_on     = ENV["TM_LINE_NUMBER"].to_i - 1
      block_top    = start_on
      block_bottom = start_on
   
      # 
      # If we are on a blank line, move up until we find something that isn't.
   
      while start_on >= 0 && lines[start_on].strip.empty?
         start_on -= 1
      end
   
      #
      # Now, find the block top and bottom. All lines in an inferred block must start on the
      # same column. We don't handle tabs, because we have no way of knowing how wide they 
      # should be. Besides, tabs are evil.
   
      block_top = block_bottom = start_on
      leading_spaces = lines[start_on].leading_spaces
   
      start_on.downto(0) do |i|
         break if lines[i].strip.empty? || lines[i].leading_spaces != leading_spaces
         block_top = i
      end
   
      start_on.upto(lines.length) do |i|
         break if lines[i].strip.empty? || lines[i].leading_spaces != leading_spaces
         block_bottom = i
      end
   end
end


#
# Output the lines before, unchanged.

0.upto(block_top - 1) do |i|
   puts lines[i]
end


#
# Process the subject lines.

begin
   trees = []
   block_top.upto(block_bottom).each do |i|
      trees << PHPLineParser.parse(lines[i], i + 1)
   end   
   
rescue ParseFailed, AlignmentTerminated
   LOG_STREAM.puts "Parse Failed"
   block_top.upto(block_bottom).each do |i|
      puts lines[i]
   end
end


#
# Output the lines after, unchanged.

(block_bottom + 1).upto(lines.length) do |i|
   puts lines[i]
end