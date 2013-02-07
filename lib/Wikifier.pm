#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# This class represents a wiki language parser.
#
package Wikifier;

use warnings;
use strict;
use feature qw(switch);

use Carp;
use Scalar::Util 'blessed';

use Wikifier::Block;
use Wikifier::Block::Main;
use Wikifier::Block::Hash;
use Wikifier::Block::Container;
use Wikifier::Block::Infobox;
use Wikifier::Block::Imagebox;
use Wikifier::Block::Section;
use Wikifier::Block::Paragraph;

###############
### PARSING ###
###############

# create a new wikifier instance.
# Required options:
#   file: the location of the file to be read.
sub new {
    my ($class, %opts) = @_;
    my $wikifier = bless \%opts, $class;
    
    # create the main block.
    $wikifier->{main_block} = my $main_block = $wikifier->create_block(
        type   => 'main',
        parent => undef     # main block has no parent.
    );
    
    # initial current hash.
    $wikifier->{current} = {
        block => $main_block 
    };
    
    # initial last hash.
    $wikifier->{last} = {
        block => undef      # main block has no parent.
    };
    
    return $wikifier;
}

# parse the file.
sub parse {
    my $wikifier = shift;
    
    # no file given.
    if (!defined $wikifier->{file}) {
        croak "no file specified for parsing.";
        return;
    }
    
    # open the file.
    open my $fh, '<', $wikifier->{file} or croak "couldn't read '$$wikifier{file}': $!";
    
    # read it line-by-line.
    while (my $line = <$fh>) {
        next unless $line;      # empty line.
        $line =~ s/\/\*(.*)\*\///g; # REALLY ILLEGAL REMOVAL OF COMMENTS.
        $line =~ s/[\r\n\0]//g; # remove returns and newlines.
        $line =~ s/^\s*//g;     # remove leading whitespace.
        $line =~ s/\s*$//g;     # remove trailing whitespace.
        next unless $line;      # line empty after removing unwanted characters.
        $wikifier->handle_line("$line ") or last;
    }
    
    # run ->parse on children.
    $wikifier->{main_block}->parse();
    
    # success.
    return 1; # return the page object.
    
}

# parse a single line.
sub handle_line {
    my ($wikifier, $line) = @_;
    
    # illegal regex filters out variable declaration. TODO.
    if ($line =~ m/^\s*\@([\w\.]+):\s*(.+);\s*$/) {
        print "variable($1): $2\n";
        return 1;
    }
    
    # illegal regex for __END__
    if ($line =~ m/^\s*__END__\s*$/) {
        print "reached __END__\n";
        return;
    }
    
    # pass on to main parser.
    $wikifier->handle_character($_) foreach split //, $line;
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
    my ($wikifier, $char) = @_;
    
    # extract parsing hashes.
    my %current = %{$wikifier->{current}};
    my %last    = %{$wikifier->{last}};

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
            
            # space.
            if ($last_char eq ' ') {
                next unless length $block_type; # ignore it if there is no block type yet.
                last unless $in_block_name; # otherwise this is the end of our type/name.
                                            # unless we're in the block name, in which
                                            # case this space is a part of the name.
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
        
        print "BLOCK: TYPE[$block_type] NAME[$block_name] $chars_scanned\n";
        
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
        if ($current{block} == $wikifier->{main_block}) {
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
    
        # if it's not a space, append to current word.
        if ($char ne ' ') {
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
    $wikifier->{current} = \%current;
    $wikifier->{last}    = \%last;
    
}

###################
### BLOCK TYPES ###
###################

# defines the types of blocks and the classes associated with them.
our %block_types = (
    main      => 'Wikifier::Block::Main',        # used only for main block.
    imagebox  => 'Wikifier::Block::Imagebox',    # displays an image with a caption.
    infobox   => 'Wikifier::Block::Infobox',     # displays a box of general information.
    section   => 'Wikifier::Block::Section',     # container for paragraphs, images, etc.
    paragraph => 'Wikifier::Block::Paragraph',   # paragraph of text.
);

# create a new block of the given type.
sub create_block {
    my ($wikifier, %opts) = @_;
    my $class = $block_types{$opts{type}};
    $opts{wikifier} = $wikifier;
    
    # no such block type; create a dummy block with no type.
    if (!defined $class) {
        $opts{type} = 'dummy';
        return Wikifier::Block->new(%opts);
    }
    
    # create a new block of the correct type.
    my $block = $class->new(%opts);
    
    return $block;
}

#################
### UTILITIES ###
#################

sub indent {
    my $string = shift;
    my $final_string = q();
    foreach my $line (split "\n", $string) {
        $final_string .= "    $line\n";
    }
    return $final_string;
}

sub safe_name {
    my $string = shift;
    $string =~ s/ /_/g;
    return $string;
}

sub unsafe_name {
    my $string = shift;
    $string =~ s/_/ /g;
    return $string;
}

######################
### FORMAT PARSING ###
######################

sub parse_formatted_text {
    my ($wikifier, $text) = @_;
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
                $string   .= $wikifier->parse_format_type($format_type);
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
    my ($wikifier, $type) = @_;
    
    # simple formatting.
    given ($type) {
    
        # italic, bold, strikethrough.
        when ('i') { return '<span style="font-style: italic;">'            }
        when ('b') { return '<span style="font-weight: bold;">'             }
        when ('s') { return '<span style="text-decoration: line-through;">' }
        when (['/s', '/b', '/i']) { return '</span>' }
    
    }
    
    # not-so-simple formatting.
    
    # a internal wiki link. TODO: don't hardcode to notroll.net.
    if ($type =~ m/\[(.+)\]/) {
        my $name      = $1;
        my $safe_name = safe_name($name);
        return "<a class=\"wiki-link-internal\" href=\"http://about.notroll.net/$safe_name\">$name</a>";
    }
    
    # a wikipedia link. TODO: don't hardcode to english wikipedia.
    if ($type =~ m/!(.+)!/) {
        my $name      = $1;
        my $safe_name = safe_name($name);
        return "<a class=\"wiki-link-external\" href=\"http://en.wikipedia.org/wiki/$safe_name\">$name</a>";
    }
    
    # leave out anything else, I guess.
    return q..;
    
}

1
