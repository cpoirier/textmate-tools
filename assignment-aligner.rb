#!/usr/bin/env ruby
#
# Assignment block tidier, version 0.9.
#
# This script can be used as a command for TextMate to align all of the equal signs 
# within a block of text, as well as all variable declarations in languages like 
# Objective-C and Java.  When using it with TextMate, set the command input to 
# "Selected Text" or "Document", and the output to "Replace Selected Text".  Map it 
# to a key equivalent, and any time you want to tidy up a block, either select it, 
# or put your cursor somewhere within it; then hit the key equivalent.  Voila.
#
# ==================================================================================
#
# NOTE: Version 0.1 of this script is included with TextMate in the "text" bundle.
# You should probably update it there.
#
# Thanks to:
#  Guillaume Cerquant (http://www.cerquant.com/)
#   - for ideas and code review
#
# ==================================================================================
#
# You can enable or disable various features by setting the ALIGNMENT_FEATURES 
# environment variable in TextMate's advanced preferences.  If you provide the this 
# variable, it should include a colon (:) separated list of the feature names to 
# enable.  All others will be disabled.  If you do not provide this environment 
# variable, suitable defaults will be used.
#
# Features:
#  align_declarations 
#   - columnate the type and variable on an typed variable declaration block
#
#  outdent_star       
#   - columnate the LHS * marker in C variable declarations and assignments
#
#  align_assignments  
#   - columnate the = in a block of assignment/declaration statements
#
#  align_comments
#   - columnate the # or // in a block of statements
#
#  debug_mode         
#   - see what the script is doing
#
#  show_errors
#   - see error messages
#
# For your convenience, the full ALIGNMENT_FEATURES string:
#  align_declarations:outdent_star:align_assignments:align_comments:show_errors:debug_mode
#
# ===================================================================================
#
# [Website]   https://github.com/cpoirier/tools/blob/master/textmate/assignment-aligner.rb
# [Copyright] Copyright Chris Poirier 2006, 2008.
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
# ==================================================================================


lines = []

begin

   feature_names   = [ :align_declarations, :outdent_star, :align_assignments, :align_comments, :show_errors, :debug_mode ]
   default_enabled = [ :align_declarations, :align_assignments, :align_comments ]
   user_enabled    = ENV.member?("ALIGNMENT_FEATURES") ? ENV["ALIGNMENT_FEATURES"].to_s.split(":") : nil

   enabled = {}
   feature_names.each do |feature_name|
      if user_enabled then
         enabled[feature_name] = user_enabled.member?(feature_name.to_s)
      else
         enabled[feature_name] = default_enabled.member?(feature_name)
      end
   end


   #
   # Load the work.

   lines = STDIN.readlines()
   selected_text = ENV.member?("TM_SELECTED_TEXT")



   #====================================================================================
   # We care about two kinds of lines: assignment statements and variable declarations.
   # In languages like Ruby, variable declarations *are* assignment statements.  However,
   # in Java and Objective-C, a type name can precede the variable name, and the 
   # assignment can be skipped altogether.  We'll try to handle both.  We'll also try to 
   # columnate the LHS * marker in Objective-C variable declarations and assignment 
   # statements, if the appropriate flag is set in enabled, above.
   #
   # We want to turn this:
   #    x = 10
   #    String x = 10;
   #    LongClassName *xyzabc = 13;
   #    Class *xyzabc[] = { abc, def, ghi };
   #    Class* xyzabc = &x;
   #    int i;
   #    boolean isItTrue;
   #    boolean meh = false;
   #
   # into this (depending on what's enabled, of course):
   #                   x        = 10
   #    String         x        = 10;
   #    LongClassName *xyzabc   = 13;
   #    Class         *xyzabc[] = { abc, def, ghi };
   #    Class         *xyzabc   = &x;
   #    int            i;
   #    boolean        isItTrue;
   #    boolean        meh      = false;
   #
   # Further, if there are no types on any of the lines, no space should be
   # left for it.  
   #
   # Everything is data driven, so let's set it up.
   #====================================================================================

   pass_names             = []
   relevant_line_patterns = []
   left_column_indices    = []
   right_column_indices   = []
   ensure_space_betweens  = []


   #
   # First up, we'll nudge any type declarations into line.  In some languages, this 
   # can include modifier keywords, which we'll columnate separately.

   if enabled[:align_declarations] then
      pass_names             << "modifiers"
      left_column_indices    << 1
      right_column_indices   << 4
      ensure_space_betweens  << 1
      relevant_line_patterns << /^
         (\s*((const|static|volatile|public|private|protected|unsigned|signed)\s+)*)   # We are looking for declaration modifiers in common languages
         (
            (?!(if|elsif|else|while|for)(\(|\s))      # We are only interested in variable declarations, so exclude other options
            \w+(\[[^\]]*\])*                          # Look for an identifier followed by an optional set of [] -- this is the type name
            (\s*\*+)*                                 # Allow for pointer markers
            \s*\w+                                    # Look for an identifier followed -- this is the variable name
            \s*(\[[^\]]*\])*                          # Allow an optional set of [] after the variable name
            \s*([+\-*\/]?=|\;)                        # Finally, require an assignment or EOS, to cut down on false positives
         )
      /x

      pass_names             << "typename"
      left_column_indices    << 1
      right_column_indices   << 10
      ensure_space_betweens  << 1
      relevant_line_patterns << /^
         (
            (  # This whole variable thing is optional, so we can columnate a mix of variable declarations and assignments
               \s*((const|static|volatile|public|private|protected|unsigned|signed)\s+)*   # Allow for modifiers
               (?!(if|elsif|else|while|for)(\(|\s))                                        # We are still only interested in variable declarations
               \w+(\[[^\]]*\])*                                                            # This is the type name
               ((\s*(?=\*))|\s+)                                                           # Require at least one space UNLESS there is a * ahead
            )?                                          
         )
         (
            (\**\s*\w+(\[[^\]]*\])*)          # Stars are up next, followed by the variable name and any optional []
            \s*([+\-*\/]?=|\;)                # Finally, require an assignment or EOS, to cut down on false positives
         )
      /x
   end


   #
   # Next, if we are doing it, we'll put all the * markers in a line, and push 
   # everything else over.

   if enabled[:outdent_star] then
      $spaced = nil
   
      pass_names             << "stars"
      left_column_indices    << 1
      right_column_indices   << 12
      ensure_space_betweens  << lambda do |m, lh_sides, rh_sides|
         $spaced = lh_sides.select{|lhs| lhs.slice(-1..-1) =~ /\s/}.length if $spaced.nil?
         0 + ($spaced == lh_sides.length ? 1 : 0)
      end

      relevant_line_patterns << /^
         (
            (  # Option 1: A variable declaration
               \s*((const|static|volatile|public|private|protected|unsigned|signed)\s+)*   # Allow for modifiers
               (?!(if|elsif|else|while|for)(\(|\s))                                        # Still only interested in variable declarations
               \w+(\[[^\]]*\])*                                                            # This is the type name
               ((\s*\*+\s*)|\s+)                                                           # Pick up any *s
            )
            |  # Option 2: Just *s or whitespace before an assignment statement
            ((\s*\*+\s*)|\s+)                                              
         )
         (
            \w+(\[[^\]]*\])*                   # On the other side of the divide is a variable name and any optional []
            \s*([+\-*\/]?=|\;)                 # And the usual assignment or EOS, to cut down on false positives
         )
      /x
   end


   #
   # Next, the easy part.  Look for an assignment operator (there are lots), and 
   # nudge it over.  Then nudge over anything that follows it.

   if enabled[:align_assignments] then
      $prefixed = nil
   
      pass_names             << "equals"
      relevant_line_patterns << /^((?!\s*(if|elsif|else|while|for|def|sub)(\(|\s))(?>([^=]*?[!=<>]=+)*).+?)([+\-*\/]?=[>]?.*)/
      left_column_indices    << 1
      right_column_indices   << 5
      ensure_space_betweens  << lambda do |m, lh_sides, rh_sides| 
         $prefixed = rh_sides.select{|rhs| rhs.slice(0..0) =~ /[+\-*\/]/}.length if $prefixed.nil?
         1 + (($prefixed > 0 && $prefixed != rh_sides.length) ? (m[3].slice(0..0) =~ /^[+\-*\/]/ ? 0 : 1) : 0)
      end

      pass_names             << "rhs"
      relevant_line_patterns << /^((?!\s*(if|elsif|else|while|for|def|sub)(\(|\s))(?>([^=]*?[!=<>]=+)*).+?=[>]?)(.*)/
      left_column_indices    << 1
      right_column_indices   << 5
      ensure_space_betweens  << 1
   end


   #
   # And, finally, look for any trailing comment, and nudge them into line.

   if enabled[:align_comments] then
      pass_names             << "comment marker"
      relevant_line_patterns << /^(.*?)((#(?!\{)|\/\/).*)/
      left_column_indices    << 1
      right_column_indices   << 2
      ensure_space_betweens  << 7

      pass_names             << "comment"
      relevant_line_patterns << /^(.*?(#(?!\{)|\/\/))(.*)/
      left_column_indices    << 1
      right_column_indices   << 3
      ensure_space_betweens  << 1
   end

 


   # 
   # Let's simplify life, by extending =~ and !~ to arrays of patterns.  We'll also add a few 
   # niceties, while we're at it.

   class Array
      def =~( string )
         i = 1
         self.each { |pattern| return i if string =~ pattern; i += 1 }
         return false
      end
   
      def select()
         results = []
         self.each do |element|
            results << element if yield(element)
         end
         return results
      end
   end

   def min( a, b )
      a > b ? b : a
   end




   #====================================================================================
   # Okay, we're ready to go.  First up, figure out the lines we need to look at.
   #====================================================================================

   #
   # If called on a selection, every assignment statement
   # is in the block.  If called on the document, we start on the 
   # current line and look up and down for the start and end of the
   # block.

   if selected_text then
      block_top    = 1
      block_bottom = lines.length
   else
 
      #
      # We start looking on the current line.  However, if the
      # current line doesn't match the pattern, we may be just
      # after or just before a block, and we should check.  If
      # neither, we are done.

      start_on      = ENV["TM_LINE_NUMBER"].to_i
      block_top     = lines.length + 1
      block_bottom  = 0
      search_top    = 1
      search_bottom = lines.length
      search_failed = false
      
      if lines[start_on - 1] !~ relevant_line_patterns then
         if lines[start_on - 2] =~ relevant_line_patterns then
            search_bottom = start_on = start_on - 1
         elsif lines[start_on] =~ relevant_line_patterns then
            search_top = start_on = start_on
         else
            search_failed = true
         end 
      end

      #
      # Now with the search boundaries set, start looking for
      # the block top and bottom.

      unless search_failed
         start_on.downto(search_top) do |number|
            if lines[number-1] =~ relevant_line_patterns then
               block_top = number
            else
               break
            end
         end
      
         start_on.upto(search_bottom) do |number|
            if lines[number-1] =~ relevant_line_patterns then
               block_bottom = number
            else
               break
            end
         end
      end
   end




   #====================================================================================
   # Now loop over the relevant lines and start nudging stuff over.
   #====================================================================================

   #
   # First up, check all the relevant lines and decide on a base indent.  Then enforce
   # it, if it seems reasonable to do so.

   indents_with_spaces = 1000000
   indents_with_tabs   = 1000000
   zero_indent         = false
   mixed_indent        = false

   block_top.upto(block_bottom) do |number|
      if lines[number - 1] =~ relevant_line_patterns then
         case lines[number - 1]
         when /^ +/
            indents_with_spaces = min( $&.length, indents_with_spaces )
         when /^\t+/
            indents_with_tabs   = min( $&.length, indents_with_tabs   )
         when /^\s+/
            mixed_indent = true
            break
         else
            zero_indent = true
         end
      end
   end

   unless mixed_indent or (indents_with_spaces < 100000 and indents_with_tabs < 100000)
      indent = zero_indent ? "" : (indents_with_spaces ? " " * indents_with_spaces : "\t" * indents_with_tabs)
      block_top.upto(block_bottom) do |number|
         lines[number - 1].sub!( /^\s+/, indent ) if lines[number - 1] =~ relevant_line_patterns
      end
   end


   #
   # Next, columnate everything.

   relevant_line_patterns.length.times do |i|
      pass_name             = pass_names[i]
      relevant_line_pattern = relevant_line_patterns[i]
      left_column_index     = left_column_indices[i]
      right_column_index    = right_column_indices[i]
      ensure_space_between  = ensure_space_betweens[i]
   

      #
      # Iterate over the block and find the best column number for the right
      # hand match to move to.  We strip off whitespace, where appropriate, to
      # ensure repeatable results.  

      use_pass    = false
      best_column = 0
      lh_sides    = []
      rh_sides    = []
      block_top.upto(block_bottom) do |number|
         line = lines[number - 1]
         if m = relevant_line_pattern.match(line) then
            if ensure_space_between.is_a?(Proc) then
               lh_sides << m[left_column_index]
               rh_sides << m[right_column_index]
            end
         
            space_offset = 0
            unless m[left_column_index].nil?
               if space_index = m[left_column_index].index(/\s+$/) then
                  space_offset = m.end(left_column_index) - space_index
               end
            
               use_pass = true
            end
         
            this_column = m.begin(right_column_index) - space_offset
            best_column = this_column if this_column > best_column
         end
      end


      #
      # Reformat the block.  

      if use_pass && best_column > 0 then
         $stderr.puts "PASS: #{pass_name}" if enabled[:debug_mode]
         block_top.upto(block_bottom) do |number|
            line = lines[number - 1].dup
         
            if m = relevant_line_pattern.match(line) then
               prefix = m.pre_match
               suffix = m.post_match
               left   = m[left_column_index].to_s.sub(/\s+$/, "")
               right  = m[right_column_index].to_s.sub(/^\s+/, "")
               space  = ensure_space_between.is_a?(Proc) ? " " * ensure_space_between.call(m, lh_sides, rh_sides) : " " * ensure_space_between

               lines[number-1] = (prefix + left).ljust(best_column) + space + right + suffix
               $stderr.puts "#{best_column}: #{lines[number-1]}" if enabled[:debug_mode]
            end
         end
      end
   end




#====================================================================================
# Only display exceptions if in debug mode.
#====================================================================================

rescue Exception => e
   if enabled[:show_errors] then
      $stderr.puts "ERROR: #{e.message}"
      e.backtrace.each do |line|
         $stderr.puts "   #{line}"
      end
      $stderr.puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
      $stderr.puts
      $stderr.puts
      $stderr.puts
   end


#====================================================================================
# Finally, output the text.
#====================================================================================

ensure
   lines.each do |line|
      puts line
   end
end


