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

use Wikifier::Block;

###############
### PARSING ###
###############

# create a new wikifier instance.
# Required options:
#   file: the location of the file to be read.
sub new {
    my ($class, %opts) = @_;
    ($opts{current}, $opts{last}) = ({}, {});
    return bless \%opts, $class;
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
#   char: the current character.
#   word: the current word. (may not yet be complete.)
#   escaped: true if the current character was escaped. (last character = \)
# 

# %last
#   char: the last parsed character.
#   word: the last full word.
#   escaped: true if the last character was escaped. (2nd last character = \)


# parse a single character.
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
        return if defined $current{word} && $current{word} eq ' ';
        $last{word} = $current{word};
        delete $current{word};
        print "last word: $last{word}\n" if defined $last{word};
    }
    
    
    # left bracket indicates the start of a block.
    when ('{') {
        return if $current{escaped};
        print "   LEFT BRACKET! last word: $last{word}\n";
        $current{blockname} = $last{word};
    }
    
    # right bracket indicates the closing of a block.
    when ('}') {
        return if $current{escaped}; # this character was escaped.
        print "   CLOSING BRACKET. end of block: $current{blockname}\n";
    }
    
    # ignore backslashes - they are handled later below.
    when ('\\') { }
    
    # any other character. append to the current word.
    default {
        $current{word}  = '' if !defined $current{word};
        $current{word} .= $char;
        print "current word: $current{word}\n";
    }
    
    }
    
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
    imagebox => 'Wikifier::Block::ImageBox',    # displays an image with a caption.
    infobox  => 'Wikifier::Block::InfoBox'      # displays a box of general information.
);

# create a new block of the given type.
sub create_block {
    my ($wikifier, $parent, $type) = @_;
    return unless defined my $class = $block_types{$type};
    
    # create a new block of the correct type.
    my $block = $class->new(
        type   => undef,    # the subclass should set this.
        parent => $parent
    );
    
    return $block;
}

1
