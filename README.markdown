# (Assignment block aligner)[https://github.com/cpoirier/tools/blob/master/textmate/assignment-aligner.rb]

Turns stuff like:

     x = 20
     long_name = 39
     really_long_name = 49

into:

     x                = 20
     long_name        = 39
     really_long_name = 49
     

and stuff like:

     x = 10
     String x = 10;
     LongClassName *xyzabc = 13;
     Class *xyzabc[] = { abc, def, ghi };
     Class* xyzabc = &x;
     int i;
     boolean isItTrue;
     boolean meh = false;
 
into (depending on what's enabled):

                    x        = 10
     String         x        = 10;
     LongClassName *xyzabc   = 13;
     Class         *xyzabc[] = { abc, def, ghi };
     Class         *xyzabc   = &x;
     int            i;
     boolean        isItTrue;
     boolean        meh      = false;


**Note:** Version 0.1 of the (assignment block aligner)[assignment-aligner.rb] ships with TextMate, but doesn't handle typed languages. The current version does. This current version also, however, contains a bug I have yet to track down, that can cause the script to go into an endless loop. If this happens to you, kill the script and undo the change in TextMate to get your original text back.



# (The Starlight theme)[https://github.com/cpoirier/tools/blob/master/textmate/Starlight.tmTheme] 

<a href='https://raw.github.com/cpoirier/tools/master/textmate/Starlight.tmTheme' title='Starlight Theme'><img src='http://courage-my-friend.org/wp-content/uploads/2008/01/starlight-theme-sample.jpeg' alt='Starlight Theme Sample' /></a>

A while back, I noticed something odd, quite by chance.  I was using a web interface to Subversion to look at a previous version of a source file I was editing.  The text was displayed in black on beige on the screen, and, just glancing down the page -- not even looking for it -- two variable name typos jumped out at me, clear as day.  I couldn't believe I'd missed them.

Well, I quickly went back to the current version of the file in TextMate, and scrolled down to that function.  And *nothing*.  Which seemed odd, because I knew I hadn't changed that function since that previous version.  So, I read through the code, line by line, and there they were: two very clear mistakes that were so obvious in "black and white", but that I *simply could not see* in passing with the syntax highlighting theme I was using at the time.

So, I thought about what had happened for a while, and here's what I came up with: the colours used by the syntax highlighting were *so* far apart in hue, saturation, or value, that they *imposed* a structure on my eye.  It said "look -- a keyword!" or "look -- an identifier", and, with *so* much emphasis on the individual parts, I lost my sense of the relationships between them -- my sense of the whole statement, of the whole function.  My ability to read the code in my peripheral vision was lost.

Until I started using TextMate, I'd never liked syntax highlighting.  It was the first thing I'd turn off when I opened any new editor.  But some of the themes available for TextMate were *really* pretty, and I was seduced by the eye candy.  :-)  And eventually, I kind of got to like knowing that I'd spelled a keyword or name correctly by the colour change.  

So, I set out to build a theme that would still provide me with that visual syntax "check", but that wouldn't render my peripheral vision useless.  And so the [Starlight theme](https://raw.github.com/cpoirier/tools/master/textmate/Starlight.tmTheme) was born.  I've been using it for quite a long while, and it works pretty well for me in both regards.  It's a very simple theme, designed primarily to show "just enough" syntax information without overwhelming the eye with noise.  It's a light on dark theme, because I get killer eyestrain trying to read dark text on a bright background.  I use it mostly for Ruby, so I can't guarantee it will do anything useful for other languages.

P.S. I use it with DejaVuSansMono 11pt, if you are trying to figure out what that font is.



