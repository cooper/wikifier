#!/usr/bin/perl
package Wikifier;

use warnings;
use strict;
use feature qw(switch);

use Carp;

# create a new wikifier instance.
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
        return if $current{escaped};
        print "   CLOSING BRACKET. last word: $last{word}\n";
    }
    
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
    
    $wikifier->{current} = \%current;
    $wikifier->{last}    = \%last;
}

1;
