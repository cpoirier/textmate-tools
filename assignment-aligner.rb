#!/usr/bin/env ruby
#
# Assignment block tidier, version 0.6.
#
# Copyright Chris Poirier 2006, 2008.
# Licensed under the Academic Free License version 3.0.
#
# This script can be used as a command for TextMate to align all of the equal signs 
# within a block of text, as well as all variable declarations in languages like 
# Objective-C and Java.  When using it with TextMate, set the command input to 
# "Selected Text" or "Document", and the output to "Replace Selected Text".  Map it 
# to a key equivalent, and any time you want to tidy up a block, either select it, 
# or put your cursor somewhere within it; then hit the key equivalent.  Voila.
#
# Note that this is the third version of the script, but it hasn't been heavily 
# tested.  You might encounter a bug or two. 
#
# Per the license, use of this script is ENTIRELY at your own risk.  See the license 
# for full details (they override anything I've said here).
#
# ==================================================================================
#
# This script lives at:
#  http://github.org/cpoirier/tools/textmate/assignment-aligner.rb
#
# Thanks to:
#  Guillaume Cerquant (http://www.cerquant.com/)
#   - for ideas and code review
#
#
# ===================================================================================
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
#  debug_mode         
#   - see what the script is doing
#


feature_names   = [ :align_declarations, :outdent_star, :align_assignments, :debug_mode ]
default_enabled = [ :align_declarations, :align_assignments ]
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



#
# We care about two kinds of lines: assignment statements and variable declarations.
# In languages like Ruby, variable declarations *are* assignment statements.  However,
# in Java and Objective-C, a type name can precede the variable name, and the assignment
# can be skipped altogether.  We'll try to handle both.  We'll also try to columnate the
# LHS * marker in Objective-C variable declarations and assignment statements, if the
# appropriate flag is set in enabled, above.

relevant_line_patterns = []
left_column_indices    = []
right_column_indices   = []
ensure_space_betweens  = []

if enabled[:align_declarations] then
   relevant_line_patterns << /^(\s*((?!(if|elsif|else)(\(|\s))\w+(\[[^\]]*\])*)((\s*(?=\*))|\s+))?((\**\s*\w+(\[[^\]]*\])*)\s*(=|\;))/
   left_column_indices    << 1
   right_column_indices   << 8
   ensure_space_betweens  << true
end

if enabled[:outdent_star] then
   relevant_line_patterns << /^((\s*(?!(if|elsif|else)(\(|\s))\w+(\[[^\]]*\])*((\s*\*+\s*)|\s+))|((\s*\*+\s*)|\s+))(\w+(\[[^\]]*\])*\s*(=|\;))/
   left_column_indices    << 1
   right_column_indices   << 10
   ensure_space_betweens  << false
end

if enabled[:align_assignments] then
   relevant_line_patterns << /^([^=()]+)(=[>]?.*)/
   left_column_indices    << 1
   right_column_indices   << 2
   ensure_space_betweens  << true

   relevant_line_patterns << /^([^=()]+=[>]?)(.*)/
   left_column_indices    << 1
   right_column_indices   << 2
   ensure_space_betweens  << true
end

 


# 
# Let's simplify life, by extending =~ and !~ to arrays of patterns.

class Array
   def =~( string )
      i = 1
      self.each { |pattern| return i if string =~ pattern; i += 1 }
      return false
   end
end




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


#
# Now, things get a bit more complicated.  We want to turn this:
#    x = 10
#    String x = 10;
#    LongClassName *xyzabc = 13;
#    Class *xyzabc[] = { abc, def, ghi };
#    Class* xyzabc = &x;
#    int i;
#    boolean isItTrue;
#    boolean meh = false;
#
# into this (depending on enabled, of course):
#                   x        = 10
#    String         x        = 10;
#    LongClassName *xyzabc   = 13;
#    Class         *xyzabc[] = { abc, def, ghi };
#    Class*         xyzabc   = &x;
#    int            i;
#    boolean        isItTrue;
#    boolean        meh      = false;
#
# Further, if there are no types on any of the lines, no space should be
# left for it.  

relevant_line_patterns.length.times do |i|
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
   block_top.upto(block_bottom) do |number|
      line = lines[number - 1]
      if m = relevant_line_pattern.match(line) then
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
      block_top.upto(block_bottom) do |number|
         line = lines[number - 1].dup
         
         if m = relevant_line_pattern.match(line) then
            prefix = m.pre_match
            suffix = m.post_match
            left   = m[left_column_index].to_s.sub(/\s+$/, "")
            right  = m[right_column_index].to_s.sub(/^\s+/, "")
            space  = ensure_space_between ? " " : ""

            lines[number-1] = (prefix + left).ljust(best_column) + space + right + suffix
            $stderr.puts "#{best_column}: #{lines[number-1]}" if enabled["debug_mode"]
         end
      end
   end
end


#
# Output the replacement text

lines.each do |line|
   puts line
end