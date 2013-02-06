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
        $wikifier->handle_line("$line ");
    }
    
    # success.
    return 1; # return the page object.
    
}

# parse a single line.
sub handle_line {
    my ($wikifier, $line) = @_;
    $wikifier->handle_character($_) foreach split //, $line;
}

# % current
#   char:       the current character.
#   word:       the current word. (may not yet be complete.)
#   escaped:    true if the current character was escaped. (last character = \)
#   block:      the current block object.
# 

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
        goto AFTER if defined $current{word} && $current{word} eq ' ';
        $last{word} = $current{word};
        delete $current{word};
        print "last word: $last{word}\n" if defined $last{word};
        continue;
    }
    
    
    # left bracket indicates the start of a block.
    when ('{') {
        continue if $current{escaped}; # this character was escaped; continue to default.
        print "   LEFT BRACKET! last word: $last{word}\n";
        $current{blockname} = $last{word}; ### XXX
        
        # create the new block.
        $current{block} = $wikifier->create_block($current{block}, $last{word});
            
    }
    
    # right bracket indicates the closing of a block.
    when ('}') {
        continue if $current{escaped}; # this character was escaped; continue to default.
        print "   CLOSING BRACKET. end of block: $current{block}{type}\n";
        
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
        # if it's escaped, continue to default.
        continue if $current{escaped};
    }
    
    # any other character.
    default {
    
        # if it's not a space, append to current word.
        if ($char ne ' ') {
            $current{word}  = '' if !defined $current{word};
            $current{word} .= $char;
            print "current word: $current{word}\n";
        }
        
        # append character to current block's content.
        
        # if the current block's content array is empty, push the character.
        if (!scalar @{$current{block}{content}}) {
            push @{$current{block}{content}}, $char;
        }
        
        # array is not empty.
        else {
            
            # if last element of the block's content is blessed, it's a child block object.
            my $last_value = $current{block}{content}[-1];
            if (blessed($last_value)) {
            
                # push the character to the content array, creating a new string element.
                push @{$current{block}{content}}, $char;
                
            }
            
            # not blessed, so simply append the character to the string.
            else {
                $current{block}{content}[-1] .= $char;
            }
            
        }
        
        
    } # end of default
    
    } # end of switch
    
    AFTER: # used in substitution of return.
    
    # set last character.
    $last{char}    = $char;
    $last{escaped} = $current{escaped};
    
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
    main     => 'Wikifier::Block::Main',        # used only for main block.
    #imagebox => 'Wikifier::Block::ImageBox',    # displays an image with a caption.
    #infobox  => 'Wikifier::Block::InfoBox'      # displays a box of general information.
);

# create a new block of the given type.
sub create_block {
    my ($wikifier, $parent, $type) = @_;
    my $class = $block_types{$type};
    
    # no such block type; create a dummy block with no type.
    if (!defined $class) {
        return Wikifier::Block->new(
            type   => 'dummy',
            parent => $parent
        );
    }
    
    # create a new block of the correct type.
    my $block = $class->new(
        type   => $type,    # the subclass should set this.
        parent => $parent
    );
    
    return $block;
}

1
