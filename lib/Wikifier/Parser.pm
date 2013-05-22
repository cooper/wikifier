# Copyright (c) 2013, Mitchell Cooper
#
# Wikifier::Parser is a function class of Wikifier which parses a wiki file.
# The parser separates the file into block types and then passes those to 
# Wikifier::BlockManager for block class loading and object creation.
#
# This class is never to be used on its own. You must use Wikifier::Wiki for a high-level
# Wiki manager or the medium-level Wikifier::Page for managing a single page.
#
package Wikifier::Parser;

use warnings;
use strict;
use feature 'switch';

use Carp;
use Scalar::Util 'blessed';

use Wikifier::Utilities qw(trim);

###############
### PARSING ###
###############

# parse a wiki file.
sub parse {
    my ($wikifier, $page, $file) = @_;
    
    # no file given.
    if (!defined $file) {
        croak "no file specified for parsing.";
        return;
    }
    
    # open the file.
    open my $fh, '<', $file or croak "couldn't read '$file': $!";
    
    # read it line-by-line.
    while (my $line = <$fh>) {
        next unless $line;      # empty line.
        $line =~ s/\/\*(.*)\*\///g; # REALLY ILLEGAL REMOVAL OF COMMENTS.
        $line =~ s/[\r\n\0]//g; # remove returns and newlines.
        $line =~ s/^\s*//g;     # remove leading whitespace.
        $line =~ s/\s*$//g;     # remove trailing whitespace.
        next unless $line;      # line empty after removing unwanted characters.
        $wikifier->handle_line($page, $line) or last;
    }
    
    # run ->parse on children.
    $page->{main_block}->parse($page);
    
    # clear parsing-related options.
    delete $wikifier->{parse_current};
    delete $wikifier->{parse_last};
    
    # success.
    return 1; # return the page object.
    
}

# parse a single line.
sub handle_line {
    my ($wikifier, $page, $line) = @_;
    
    # illegal regex filters out variable declaration.
    if ($line =~ m/^\s*\@([\w\.]+):\s*(.+);\s*$/) {
        $page->set($1, $wikifier->parse_formatted_text($page, $2));
        return 1;
    }
    
    # illegal regex for __END__
    if ($line =~ m/^\s*__END__\s*$/) {
        return;
    }
    
    # pass on to main parser.
    $wikifier->handle_character($page, $_) foreach (split(//, $line), "\n");
    return 1;
}

# % current
#   char:       the current character.
#   word:       the current word. (may not yet be complete.)
#   escaped:    true if the current character was escaped. (last character = \)
#   block:      the current block object.
#   ignored:    true if the character is a master parster character({, }, etc.).

# %last
#   char:       the last parsed character.
#   word:       the last full word.
#   escaped:    true if the last character was escaped. (2nd last character = \)
#   block:      the current block object's parent block object.


# parse a single character.
# note: never return from this method; instead goto AFTER.
sub handle_character {
    my ($wikifier, $page, $char) = @_;
    
    # extract parsing hashes.
    my %current = %{$wikifier->{parse_current}};
    my %last    = %{$wikifier->{parse_last}};

    # set current character.
    $current{char} = $char;
    
    given ($char) {
    
    # space. terminates a word.
    # delete the current word, setting its value to the last word.
    when (' ') {
    
        # that is, unless the current word a space.
        # note: I can't remember why I felt the need for this code.
        if (!(defined $current{word} && $current{word} eq ' ')) {
            $last{word} = delete $current{word};
            continue;
        }
    }
    
    # left bracket indicates the start of a block.
    when ('{') {
        $current{ignored} = 1;
        continue if $current{escaped}; # this character was escaped; continue to default.
       
        # now we must remove the new block type from the
        # current block's last content element.
        
        # set some initial variables for the loop.
        my $content       = $current{block}{content}[-1];
        my $block_type    = my $block_name = q..;
        my $in_block_name = my $chars_scanned = 0;
        
        # chop one character at a time from the end of the content.
        while (my $last_char = chop $content) { $chars_scanned++;
            
            # space. section section [block name] {
            if ($last_char eq ' ') {
                
                # this is space within [].
                if ($in_block_name) {
                    # append it to the block name.
                    # continue.
                }
                
                # not in the block name.
                else {
                
                    # spaces between things:
                    # section [block name] {
                    #        ^            ^
                    # ignore them entirely.
                    if (!length $block_type) {
                        next;
                    }
                    
                    # space before the block type:
                    #  section [block name] {
                    # ^
                    # marks the end of parsing.
                    last;
            
                }
                
                # FIXME: in the rare situation that a file may start with a block
                # with no prefixing newlines or spaces, this will not work, and the
                # wikifier will probably output nothing.
                # a simple workaround could be to inject a newline before the beginning of
                # the file's first line during file parsing.
                
            }
            
            # ignore newlines.
            if ($last_char eq "\n") {
                next;
            }
            
            # entering block name.
            if ($last_char eq ']') {
                $in_block_name = 1;
                next;
            }
            
            # exiting block name.
            if ($last_char eq '[') {
                $in_block_name = 0;
                next;
            }
            
            # we are in the block name, so add this character to the front.
            if ($in_block_name) {
                $block_name = $last_char.$block_name;
                next;
            }
            
            # not in block name, so it's part of the type.
            $block_type = $last_char.$block_type;
            
        }
        
        # remove the block type and name from the current block's content.
        #
        # note: it is very likely that a single space will remain, but this will later
        # ..... be trimmed out by a further cleanup.
        $current{block}{content}[-1] = substr($current{block}{content}[-1], 0, -$chars_scanned);
        
        # create the new block.
        $current{block} = $wikifier->create_block(
            parent => $current{block},
            type   => $block_type,
            name   => $block_name
        );
       
            
    }
    
    # right bracket indicates the closing of a block.
    when ('}') {
        $current{ignored} = 1;
        continue if $current{escaped}; # this character was escaped; continue to default.
        
        # we cannot close the main block.
        if ($current{block} == $page->{main_block}) {
            croak "attempted to close main block";
            return;
        }
        
        # close the block, returning to its parent.
        $current{block}{closed} = 1;
        push @{$current{block}{parent}{content}}, $current{block};
        $current{block} = $current{block}{parent};
        
    }
    
    # ignore backslashes - they are handled later below.
    when ('\\') {
        # this character should NEVER be ignored.
        # if it's escaped, continue to default.
        continue if $current{escaped};
    }
    
    # any other character.
    default {
    
        # at this point, anything that needs escaping should have been handled by now.
        # so, if this character is escaped and reached all the way to here, we will
        # pretend it's not escaped by reinjecting a backslash. this allows further parsers
        # to handle escapes (in particular, the formatting parser.)
        my $append = $char;
        if (!$current{ignored} && $current{escaped}) {
            $append = "$last{char}$char";
        }
    
        # if it's not a space or newline, append to current word.
        if ($char ne ' ' && $char ne "\n") {
            $current{word}  = '' if !defined $current{word};
            $current{word} .= $append;
        }
        
        # append character to current block's content.
        
        # if the current block's content array is empty, push the character.
        if (!scalar @{$current{block}{content}}) {
            push @{$current{block}{content}}, $append;
        }
        
        # array is not empty.
        else {
            
            # if last element of the block's content is blessed, it's a child block object.
            my $last_value = $current{block}{content}[-1];
            if (blessed($last_value)) {
            
                # push the character to the content array, creating a new string element.
                push @{$current{block}{content}}, $append;
                
            }
            
            # not blessed, so simply append the character to the string.
            else {
                $current{block}{content}[-1] .= $append;
            }
            
        }
        
        
    } # end of default
    
    } # end of switch
    
    AFTER: # used in substitution of return.
    
    # set last stuff for next character.
    $last{char}       = $char;
    $last{escaped}    = $current{escaped};
    $current{ignored} = 0;
    
    # the current character is \, so set $current{escaped} for the next character.
    # unless, of course, this escape itself is escaped. (determined with current{escaped})
    if ($char eq '\\' && !$current{escaped}) {
        $current{escaped} = 1;
    }
    
    # otherwise, set current{escaped} to 0.
    else {
        $current{escaped} = 0;
    }
    
    ### do not do anything below that depends on $current{escaped} ###
    ###   because it has already been modified for the next char   ###
    
    # replace parsing hashes.
    $wikifier->{parse_current} = \%current;
    $wikifier->{parse_last}    = \%last;
    
}

1
