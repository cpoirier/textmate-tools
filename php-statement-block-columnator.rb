#!/usr/bin/env ruby
# =============================================================================================
# PHP statement block columnator
#
# This script can be used as a command for TextMate to columnate the major structures within
# a block of similar PHP statements. When using it with TextMate, set the command input to 
# "Selected Text" or "Document", and the output to "Replace Selected Text". Map it to a key 
# equivalent, and any time you want to tidy up a block, either select it, or put your cursor 
# within or just below it, and voila.
#
# The script is loosely based on my assignment block aligner that I wrote back in 2006. This 
# version attempts to align along more structures, and is specifically designed for use with 
# PHP, as it has to know a lot about the language in order to work. Versions for other 
# languages may follow.
#
# [Website]   http://github.com/cpoirier/textmate-tools/php-statement-block-columnator.rb
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

LOG_CONTROL       = {:parse => false, :tree => false}
LOG_STREAM        = $stderr
ALIGN_SEMICOLONS  = false
TAB_WIDTH         = 2




# =============================================================================================
# BASIC COMPONENTS

class ColumnationTerminated < Exception ; end    # Raised when we just need to bail out.
class ParseFailed           < Exception ; end    # Raised when parsing fails.

class Product
   def initialize( type )
      @type = type
   end
   
   def is?( type )
      @type == type
   end
   
   def ===( type )
      (@type == type) || super
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
   
   def is_an?( value )
      is_a?(value)
   end
      
end

class String
   def leading_spaces()
      self =~ /^( +)/ ? $1.length : 0
   end
end

class ArrayOfArrays
   def initialize( count )
      super(count) { Hash.new }
   end
end

class Array
   def to_s()
      collect{|element| element.to_s}.join("")
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
   
   def reset()
      @pos = 0
   end
   
   
   @@whitespace    = /^[ \t\r\n]+/
   @@numbers       = /^((\d+(?:\.\d*)?)|(\.\d+))/
   @@words         = /^(\$?[a-zA-Z_][a-zA-Z0-9_]*)/
   @@in_equalities = /^(==(=?)|!=(=*))/ 
   @@comparators   = /^(>(=?)|<(=?)|<>)/
   @@assigners     = /^(=>|([-+*\/%.^]|<<|>>)?\=)/
   @@scopers       = /^(->|::)/
   @@structural    = /^([(){}\[\]?:,@;])/
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
            raise ColumnationTerminated.new("cannot tokenize: #{@line[@pos]}")
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
   
   def method_missing( symbol, *args, &block )
      return super unless args.empty? && block.nil?
      return super unless @elements.member?(symbol)
      @elements[symbol]
   end
   
   def to_s()
      @elements.collect{|name, element| element.to_s}.join("")
   end
end


class PHPLineParser
   
   def self.parse( line, number = 0 )
      result = nil
      
      self.new(PHPTokenizer.new(line, number)).tap do |parser|
         parser.instance_eval do
            begin
               result = parse_statements()
            rescue ParseFailed => e
               reset()
               attempt do
                  result = parse_list_item()
                  fail_unless_done()
               end
               
               result or raise
            end
            
            if result then 
               log(:tree) do |stream|
                  stream.puts ""
                  stream.puts "   #{line}"
                  result.dump("   ", stream)
                  stream.puts ""
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
   
   def reset()
      @lookahead.clear()
      @tokenizer.reset()
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
      log(:parse) do |stream| 
         stream.puts "   ==> attempting to consume one of #{types.collect{|t| t.to_s}.join(", ")}"
      end

      types.each do |type|
         if la() == type then
            return @lookahead.shift.tap do |consumed|
               log(:parse) do |stream| 
                  stream.puts "   ==> consumed (#{consumed.type} #{consumed})"
               end
            end
         end
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
   
   def fail_unless_done()
      la() == nil or fail()
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

   def parse_list_item()
      Expression.new(:list_item, :expression => fail_unless(parse_expression()), :comma => (la() == (:comma) ? consume(:comma) : nil))
   end
   
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
      parse_sequence_or_expression()
   end
   
   
   def parse_sequence_or_expression()
      trace()
      parse_binary_operator_expression(:sequence_or, :keyword_or, :parse_sequence_xor_expression, :parse_sequence_xor_expression)
   end
   
   
   def parse_sequence_xor_expression()
      trace()
      parse_binary_operator_expression(:sequence_xor, :keyword_xor, :parse_sequence_and_expression, :parse_sequnce_and_expression)
   end
   
   
   def parse_sequence_and_expression()
      trace()
      parse_binary_operator_expression(:sequence_and, :keyword_and, :parse_assignment_expression, :parse_assignment_expression)
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
      la() == :exclamation ? Expression.new(:logical_not, :op => consume(:exclamation), :expression => fail_unless(parse_logical_not_expression())) : parse_at_expression()
   end
   
   def parse_at_expression()
      trace()
      la() == :at ? Expression.new(:error_suppression, :op => consume(:at), :expression => fail_unless(parse_at_expression())) : parse_lifecycle_expression()
   end
   
   def parse_lifecycle_expression()
      trace()
      if la() == :keyword_new || la() == :keyword_clone then
         operator = consume()
         if la(1) == :word and la(2) == :open_paren then
            Expression.new(:lifecycle_expression, :op => operator, :expression => fail_unless(parse_function_call_expression()))
         else
            Expression.new(:lifecycle_expression, :op => operator, :expression => consume(:word))
         end
      else
         parse_parenthesized_expression()
      end 
   end
   
   def parse_parenthesized_expression()
      trace()
      if la() == :open_paren then
         Expression.new(:parenthesized_expression, :open_paren => consume(:open_paren), :body => parse_expression(), :close_paren => consume(:close_paren))
      else
         parse_unary_expression()
      end
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
      expression = parse_object_expression()
      la_is_one_of?(:plusplus, :minusminus) ? Expression.new(:postfix, :expression => expression, :op => consume()) : expression
   end
   
   def parse_object_expression()
      expression = parse_function_call_expression()
      if la() == :scoper then
         expression = Expression.new(:object_expression, :expression => expression, :scoper => consume(:scoper), :offset => fail_unless(parse_object_expression()))
      end
      expression
   end
      
   def parse_function_call_expression()
      expression = parse_simple_expression()
      if la() == :open_paren then
         expression = Expression.new(:function_call, :name => expression, :open_paren => consume(:open_paren), :parameters => attempt_optional{parse_comma_list()}, :close_paren => consume(:close_paren))
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
      first = parse_expression()
      la() == :comma ? Expression.new(:comma_list, :first => first, :comma => consume(:comma), :rest => fail_unless(parse_comma_list())) : first
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

class Cell
   def initialize( group, contents, index, flags = {} )
      @group    = group
      @contents = contents
      @index    = index
      @flags    = flags
      @unspaced = nil
   end
   
   attr_accessor :contents
   
   def matches?( *types )
      @contents.is_an?(Expression) && types.any?{|type| @contents === type} && (!block_given? || yield(@contents))
   end
   
   def split( catchall, *on )
      if matches?(*on) then
         @contents = yield(@contents)
      elsif catchall then
         @contents = catchall.add(@contents)
      end
   end
   
   
   def to_s()
      @group.format(unspaced(), @index, @flags)
   end
   
   def min_width()
      unspaced().length
   end
   
   def integer?()
      unspaced() =~ /^\d+$/
   end
   
   def unspaced()
      @unspaced ||= @contents.to_s
   end
end


class CellGroup
   def initialize( properties = {} ) 
      @cells             = []
      @properties        = properties
      @variable_width    = properties.fetch(:variable_width, false)
      @offset_width      = properties.fetch(:offset_width  , nil  )
      @width             = nil
      @before            = properties.fetch(:before        , ""   )
      @after             = properties.fetch(:after         , ""   )
      @justification     = properties.fetch(:justification , :left)
   end
   
   def empty?()
      @cells.empty?
   end
   
   def width()
      if @variable_width && justification() != :right then
         0
      elsif @width.nil? then
         @width = @cells.collect{|cell| cell.min_width}.max()
      else 
         @width
      end
   end
   
   def offset_width( index )
      if @max_width.nil? then
         @max_width = @cells.collect{|cell| cell.min_width}.max()
      end
      
      @max_width - @cells[index].min_width
   end
   
   def justification()
      @justification
   end
   
   def several_integers?()
      if !defined?(@several_integers) then 
         count = @cells.count{|cell| cell.integer?}
         @several_integers = (count > 1)
      end
      
      @several_integers
   end
   
   def format( string, index, overrides = {} )
      before = overrides.fetch(:before        , @before)
      after  = overrides.fetch(:after         , @after )
      width  = overrides.fetch(:variable_width, false  ) ? 0 : width()
      rjust  = overrides.fetch(:justification , justification()) == :right || (several_integers? && string =~ /^\d+$/)

      before + (rjust ? string.rjust(width) : string.ljust(width)) + after
   end

   def split( catchall, *on )
      @cells.each do |cell|
         cell.split(catchall, *on) do |expression|
            yield(expression)
         end
      end
   end
   
   def each()
      @cells.each do |cell|
         yield(cell)
      end
   end

   def add( contents, flags = {} )
      Cell.new(self, contents, @cells.length, flags).tap do |cell|
         @cells << cell
      end
   end

   def to_s()
      @cells.collect{|cell| cell.to_s}.join("")
   end
   
   def derive_new( properties = {} )
      column = properties.fetch(:column)
      of     = properties.fetch(:of    )
      
      properties[:variable_width] = true if column == of and @variable_width
      self.class.new( properties )
   end


   def columnate()
      case @cells[0].contents.type
      when :list_item
         columnate_over_list_items()
      else
         columnate_over_statements()
      end
      
      self
   end
   
   def columnate_over_statements()
      first_group = derive_new(:column => 1, :of => 2)
      rest_group  = derive_new(:column => 2, :of => 2, :before => " ")
      split(first_group, :statement_sequence) do |sequence|
         [first_group.add(sequence.first), rest_group.add(sequence.rest)]
      end
      
      first_group.columnate_over_statement(!rest_group.empty?)
      rest_group.columnate_over_statements() unless rest_group.empty?
   end
   
   def columnate_over_statement( align_semicolons = false )
      body_group = derive_new(:column => 1, :of => 2, :variable_width => (align_semicolons || ALIGN_SEMICOLONS ? false : true))
      semi_group = derive_new(:column => 2, :of => 2)
      split(nil, :statement) do |statement|
         [body_group.add(statement.body), semi_group.add(statement.terminator)]
      end
      
      body_group.columnate_by_pattern()
   end
   
   
   def columnate_over_list_items()
      expression_group = derive_new(:column => 1, :of => 2)
      comma_group      = derive_new(:column => 2, :of => 2)
      
      each do |cell|
         item = cell.contents
         if cell.matches?(:list_item) then            
            cell.contents = [expression_group.add(item.expression), comma_group.add(item.comma)]
         end
      end

      columnate_by_pattern()
      expression_group.columnate_by_pattern()
   end

   def columnate_by_pattern()
      unless empty?
         types = [:sequence_or, :sequence_and, :sequence_xor]
         columnate_sequences(types) if @cells.any?{|cell| cell.matches?(*types)}
         
         types = [:logical_or, :logical_and, :bitwise_or, :bitwise_and, :bitwise_shift, :addition, :multiplication]
         columnate_binary_expressions(types) if @cells.any?{|cell| cell.matches?(*types)}
         
         types = [:object_expression]
         columnate_object_expressions(types) if @cells.any?{|cell| cell.matches?(*types)}

         types = [:assignment, :equality_test, :comparison_test]
         columnate_binary_expressions(types) if @cells.any?{|cell| cell.matches?(*types)}
         
         types = [:ternary_expression]
         columnate_ternary_expressions(types) if @cells.any?{|cell| cell.matches?(*types)}

         types = [:error_suppression, :prefix, :logical_not]
         columnate_prefix_expressions(types) if @cells.any?{|cell| cell.matches?(*types)}

         types = [:lifecycle_expression]
         columnate_lifecycle_expressions(types) if @cells.any?{|cell| cell.matches?(*types)}

         types = [:parenthesized_expression]
         columnate_parenthesized_expressions(types) if @cells.any?{|cell| cell.matches?(*types)}

         columnate_function_calls() if @cells.any?{|cell| cell.matches?(:function_call)}
         
         columnate_array_indices() if @cells.any?{|cell| cell.matches?(:array_expression)}
      end
   end
   
   def columnate_sequences( types )
      lhs_group = derive_new(:column => 1, :of => 3)
      op_group  = derive_new(:column => 2, :of => 3, :before => " ", :after => " ")
      rhs_group = derive_new(:column => 3, :of => 3)

      split(lhs_group, *types) do |expression|
         [lhs_group.add(expression.lhs), op_group.add(expression.op), rhs_group.add(expression.rhs)]
      end

      lhs_group.columnate_by_pattern()
      rhs_group.columnate_by_pattern()
   end
   
   
   def columnate_binary_expressions( types )
      lhs_group = derive_new(:column => 1, :of => 3)
      op_group  = derive_new(:column => 2, :of => 3, :before => " ", :after => " ", :justification => :right)
      rhs_group = derive_new(:column => 3, :of => 3)

      split(nil, *types) do |expression|
         [lhs_group.add(expression.lhs), op_group.add(expression.op), rhs_group.add(expression.rhs)]
      end
      
      lhs_group.columnate_by_pattern()
      rhs_group.columnate_by_pattern()
   end
   
   
   def columnate_object_expressions( types )
      expression_group = derive_new(:column => 1, :of => 3, :variable_width => true)
      op_group         = derive_new(:column => 2, :of => 3)
      offset_group     = derive_new(:column => 3, :of => 3)
      
      each do |cell|
         e = cell.contents
         if cell.matches?(*types) then
            cell.contents = [expression_group.add(e.expression), op_group.add(e.scoper), offset_group.add(e.offset)]
         else
            cell.contents = expression_group.add(e)
         end
      end
      
      expression_group.columnate_by_pattern()
      offset_group.columnate_by_pattern()
   end
   
   def columnate_ternary_expressions( types )
      condition_group = derive_new(:column => 1, :of => 5)
      question_group  = derive_new(:column => 2, :of => 5, :before => " ", :after => " ")
      true_group      = derive_new(:column => 3, :of => 5)
      colon_group     = derive_new(:column => 4, :of => 5, :before => " ", :after => " ")
      false_group     = derive_new(:column => 5, :of => 5)
      
      split(nil, *types) do |expression|
         [condition_group.add(expression.condition), question_group.add(expression.question), true_group.add(expression.true_branch), colon_group.add(expression.colon), false_group.add(expression.false_branch)]
      end
      
      condition_group.columnate_by_pattern()
      true_group.columnate_by_pattern()
      false_group.columnate_by_pattern()
   end


   def columnate_prefix_expressions( types, space_after = "" )
      op_group   = derive_new(:column => 1, :of => 2, :after => space_after, :justification => :right)
      body_group = derive_new(:column => 2, :of => 2)
      
      each do |cell|
         expression = cell.contents
         if cell.matches?(*types) then
            cell.contents = [op_group.add(expression.op), body_group.add(expression.expression)]
         else
            cell.contents = [op_group.add(""           ), body_group.add(expression           )]
         end
      end
      
      body_group.columnate_by_pattern() unless body_group.empty?
   end
   
   def columnate_lifecycle_expressions( types )
      op_group   = derive_new(:column => 1, :of => 2, :after => " ", :justification => :right)
      body_group = derive_new(:column => 2, :of => 2)
      
      split(nil, *types) do |expression|
         [op_group.add(expression.op), body_group.add(expression.expression)]
      end
      
      body_group.columnate_by_pattern() unless body_group.empty?
   end
   

   def columnate_parenthesized_expressions( types )
      open_group  = derive_new(:column => 1, :of => 3)
      body_group  = derive_new(:column => 2, :of => 3)
      close_group = derive_new(:column => 3, :of => 3)
      
      split(nil, *types) do |expression|
         [open_group.add(expression.open_paren), body_group.add(expression.body), close_group.add(expression.close_paren)]
      end
      
      body_group.columnate_by_pattern()
   end
   
   
   def columnate_function_calls()      
      names = Hash.new{|hash, key| hash[key] = []}
      each do |cell|
         if cell.matches?(:function_call, :list_receiver) then
            names[cell.contents.name.to_s] << count_parameters(cell.contents.parameters)
         end
      end
      
      names.each do |name, counts|
         count       = counts.max()
         columns     = 3 + (count > 0 ? count * 2 - 1 : 0) 
         name_group  = derive_new(:column => 1, :of => columns)
         open_group  = derive_new(:column => 2, :of => columns)
         tail_groups = []
         (columns - 2).times do |i|
            tail_groups << derive_new(:column => 3 + i, :of => columns)
         end
         
         each do |cell|
            if cell.matches?(:function_call, :list_receiver){|expression| expression.name.to_s == name} then
               expression = cell.contents
               contents   = []
               contents  << name_group.add(expression.name)
               contents  << open_group.add(expression.open_paren)
               
               index = 0
               flatten_parameters(expression.parameters).each do |parameter|
                  if parameter.type == :comma then
                     contents << tail_groups[index].add(parameter, :after => " ")
                  else
                     contents << tail_groups[index].add(parameter)
                  end
                  
                  index += 1
               end
               
               contents << tail_groups[index].add(expression.close_paren, :variable_width => true);
               
               cell.contents = contents
            end
         end
         
         tail_groups.each do |tail_group|
            tail_group.columnate_by_pattern()
         end
      end
  end
   
   
   def columnate_comma_lists()
      first_group = derive_new(:column => 1, :of => 3)
      comma_group = derive_new(:column => 2, :of => 3, :after => " ")
      rest_group  = derive_new(:column => 3, :of => 3)
      
      each do |cell|
         comma_list = cell.contents
         if cell.matches?(:comma_list) then
            cell.contents = [first_group.add(comma_list.first), comma_group.add(comma_list.comma), rest_group.add(comma_list.rest)]
         end
      end
      
      columnate_by_pattern()
      first_group.columnate_by_pattern()
      rest_group.columnate_by_pattern()
      rest_group.columnate_comma_lists() unless rest_group.empty?
   end
   
   
   def columnate_array_indices()
      array_group = derive_new(:column => 1, :of => 4)
      open_group  = derive_new(:column => 2, :of => 4)
      index_group = derive_new(:column => 3, :of => 4)
      close_group = derive_new(:column => 4, :of => 4)
      
      split(nil, :array_expression) do |expression|
         [array_group.add(expression.array), open_group.add(expression.open_bracket), index_group.add(expression.index), close_group.add(expression.close_bracket)]
      end
      
      index_group.columnate_by_pattern()
   end
   
   def count_parameters( parameters )
      return 0 if parameters.nil?
      return 1 unless parameters.type == :comma_list
      return 1 + count_parameters(parameters.rest)
   end
   
   def flatten_parameters( parameters )
      return [] if parameters.nil?
      return [parameters] unless parameters.type == :comma_list
      return [parameters.first, parameters.comma] + flatten_parameters(parameters.rest)
   end
   
end






# =============================================================================================
# PROCESS THE INPUT


lines          = STDIN.readlines()
block_top      = 0
block_bottom   = lines.length - 1
leading_spaces = lines[block_top].leading_spaces


#
# If called from TextMate, figure out what lines to process.

if ENV.member?("TM_LINE_NUMBER") then
   selected_text = ENV.member?("TM_SELECTED_TEXT")

   #
   # If called on a selection, every statement is in the block.  If called on the document, we 
   # start on the current line and look and down for the start and end of the block.

   unless selected_text 
      start_on     = ENV["TM_LINE_NUMBER"].to_i - 1
      block_top    = start_on
      block_bottom = start_on
   
      # 
      # If we are on a blank line or a line with just a closing brace, move up until we find 
      # something that isn't.
   
      while start_on >= 0 && (lines[start_on].nil? || lines[start_on].strip.empty? || lines[start_on].strip == "}")
         start_on -= 1
      end
   
      #
      # Now, find the block top and bottom. All lines in an inferred block must start on the
      # same column. We convert leading tabs to spaces first, in an attempt to provide reasonable
      # behaviour in the presence of such invisible evil. Unfortunately, evil will be evil, and 
      # this may not actually improve things.
   
      block_top = block_bottom = start_on
      leading_spaces = lines[start_on].gsub("\t", " " * TAB_WIDTH).leading_spaces
   
      start_on.downto(0) do |i|
         break if lines[i].nil? || lines[i].strip.empty? || lines[i].leading_spaces != leading_spaces
         block_top = i
      end
   
      start_on.upto(lines.length) do |i|
         break if lines[i].nil? || lines[i].strip.empty? || lines[i].leading_spaces != leading_spaces
         block_bottom = i
      end
   end
end


#
# Output the lines before, unchanged.

if block_top > 0 then
   0.upto(block_top - 1) do |i|
      puts lines[i]
   end
end


#
# Process the subject lines.

begin
   cells = CellGroup.new(:variable_width => true, :before => (" " * leading_spaces), :after => "\n")
   block_top.upto(block_bottom).each do |i|
      cells.add(PHPLineParser.parse(lines[i], i + 1))
   end   
   
   cells.columnate()
   cells.each do |cell|
      puts cell.to_s.sub(/\s+$/, "")
   end
   
rescue ParseFailed, ColumnationTerminated
   block_top.upto(block_bottom).each do |i|
      puts lines[i]
   end
end


#
# Output the lines after, unchanged.

if block_bottom + 1 < lines.length then
   (block_bottom + 1).upto(lines.length - 1) do |i|
      puts lines[i]
   end
end