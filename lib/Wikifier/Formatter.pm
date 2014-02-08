# Copyright (c) 2014, Mitchell Cooper
#
# Wikifier::Formatter is in charge of text formatting. Block types use the functions
# provided by the Formatter to convert formatted wiki source such as '[b]hello[/b]' to
# formatted XHTML.
#
package Wikifier::Formatter;

use warnings;
use strict;
use feature 'switch';

use Scalar::Util ();

use Wikifier::Utilities qw(safe_name trim);

######################
### FORMAT PARSING ###
######################

sub parse_formatted_text {
    my ($wikifier, $page, $text) = @_;
    my $string = q();
    
    my $last_char    = q();  # the last parsed character.
    my $in_format    = 0;    # inside a formatting element.
    my $format_type  = q();  # format name such as 'i' or '/b'
    my $escaped      = 0;    # this character was escaped.
    my $next_escaped = 0;    # the next character will be escaped.
    my $ignored      = 0;    # this character is a parser syntax character.
    
    # parse character-by-character.
    CHAR: foreach my $char (split '', $text) {
        $next_escaped = 0;
        given ($char) {
        
        # escapes.
        when ('\\') {
            $ignored = 1; # the master parser does not ignore this...
                          # I'm not sure why this works this way, but it does.
                          # It shall stay this way until I find a reason to change it.
                          
            continue if $escaped; # this backslash was escaped.
            $next_escaped = 1;
        }
        
        # [ marks the beginning of a formatting element.
        when ('[') {
            continue if $escaped;
            
            # if we're in format already, it's a [[link]].
            if ($in_format && $last_char eq '[') {
                $format_type .= $char;
                
                # skip to next character.
                $last_char = $char;
                next CHAR;
                
            }

            # we are now inside the format type.
            $in_format = 1;
            $format_type = q();
            
        }
        
        # ] marks the end of a formatting element.
        when (']') {
            continue if $escaped;
            
            # ignore it for now if it starts with [ and doesn't end with ].
            # this means it's a [[link]] which hasn't yet handled the second ].
            my $first = substr $format_type, 0, 1;
            my $last  = substr $format_type, -1, 1;
            if ($in_format && $first eq '[' && $last ne ']') {
                $format_type .= $char;
                $in_format    = 0;
            }
            
            
            # otherwise, the format type is ended and must now be parsed.
            else {
                $string   .= $wikifier->parse_format_type($page, $format_type);
                $in_format = 0;
            }
            
        }
        
        # any other character.
        default {
        
            # if this character is escaped and not ignored
            # for escaping, reinject the last char (backslash.)
            my $append = $char;
            if (!$ignored && $escaped) {
                $append = $last_char.$char;
            }
        
            # if we're in the format type, append to it.
            if ($in_format) {
                $format_type .= $append;
            }
            
            # it's any regular character, either within or outside of a format.
            else {
                $string .= $append;
            }
            
        }
        
        } # end of switch
        
        # set last character and escape for next character.
        $last_char = $char;
        $escaped   = $next_escaped;
        $ignored   = 0;
        
    }
    
    return $string;
}

# parses an individual format type, aka the content in [brackets].
# for example, 'i' for italic. returns the string generated from it.
sub parse_format_type {
    my ($wikifier, $page, $type) = @_;
    
    given ($type) {
    
    # italic, bold, strikethrough.
    when ('i') { return '<span style="font-style: italic;">'            }
    when ('b') { return '<span style="font-weight: bold;">'             }
    when ('s') { return '<span style="text-decoration: line-through;">' }
    when (['/s', '/b', '/i']) { return '</span>' }
    
    # inline quote.
    when ( 'q') { return '"<span style="font-style: italic;">'  }
    when ('/q') { return '</span>"'                             }
    
    # new line.
    when (['nl', 'br']) { return '<br />' }
    
    # variable.
    when (/^@([\w.]+)$/) {
        my $var = $page->get($1);
        return defined $var ? $var : '<span style="color: red; font-weight: bold;">(null)</span>';
    }
    
    # a link in the form of [[link]], [!link!], or [$link$]
    when (/^([\!\[\$]+?)(.+)([\!\]\$]+?)$/) { # inner match should be most greedy.
    
        my ($link_char, $inner, $link_type) = (trim($1), trim($2));
        my ($target, $text, $title) = ($inner, $inner, '');
        
        # format is <text>|<target>
        if ($inner =~ m/^(.+?)\|(.+)$/) {
            $text   = trim($1);
            $target = trim($2);
        }
        
        # internal wiki link [[article]]
        if ($link_char eq '[') {
            $link_type = 'internal';
            $title     = $target;
            $target    = $page->wiki_info('wiki_root').q(/).safe_name($target, 1);
        }
        
        # external wiki link [!article!]
        elsif ($link_char eq '!') {
            $link_type = 'external';
            $title     = $page->wiki_info('external_name').q(: ).$target;
            $target    = $page->wiki_info('external_root').q(/).safe_name($target);
        }
        
        # other non-wiki link [$url$]
        elsif ($link_char eq '$') {
            $link_type = 'other';
            $title     = 'external link';
        }
        
        $title = qq( title="$title") if $title;
        return qq{<a class="wiki-link-$link_type" href="$target"$title>$text</a>};
    }
    
    # fake references.
    when ('ref') {
        $page->{reference_number} ||= 1;
        my $ref = $page->{reference_number}++;
        return qq{<sup style="font-size: 75%"><a href="#">[$ref]</a></sup>};
    }
    
    # real references.
    when (\&Scalar::Util::looks_like_number) {
        return qq{<sup style="font-size: 75%"><a href="#wiki-ref-$type">[$type]</a></sup>};
    }
    
    } # end switch
  
    # leave out anything else, I guess.
    return q..;
    
}

1
