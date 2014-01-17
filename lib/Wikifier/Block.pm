#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# Wikifier::Block represents a parsing block, such a section, paragraph, infobox, etc.
# With the exception of the main block, each block has a parent block. The main block is
# the implied block which surrounds all other blocks.
#
# This class is subclassed by several specific types of blocks, each which provides its
# own specific functionality.
#
package Wikifier::Block;

use warnings;
use strict;
use feature qw(switch);

# Required properties of blocks.
#   
#   parent:     the parent block object. (for main block, undef)
#   type:       the name type of block, such as 'imagebox', 'paragraph', etc.
#   content:    the inner content of the block, an arrayref of strings and child blocks.
#   closed:     parser sets this true after the block has been closed.
#   name:       the name of the block or an empty string if it has no name.

# Required methods of blocks.
#   parse:  parse the inner contents of the block.
#   result: the resulting HTML from the block's content.


# Create a new block.
#
# Required arguments:
#   parent:     the parent block. (for main block, undef)
#   type:       the name of the block, such as 'imagebox', 'paragraph', etc.
#   wikifier:   the wikifier object. (FIXME: looping references)
#
# For subclasses, the type is provided automatically.
# This should rarely be used directly; use $wikifier->create_block($parent, $type).
#
sub new {
    my ($class, %opts) = @_;
    $opts{content} ||= [];
    return bless \%opts, $class;
}

# parse the contents.
sub parse {
    my $block = shift;
    
    # parse property.
    if ($block->{parse}) {
        return $block->{parse}->($block, @_);
    }
    
    # _parse method.
    if ($block->can('_parse')) {
        return $block->_parse(@_);
    }
    
    return;
}

# HTML result.
sub result {
    my $block = shift;
    
    # result property.
    if ($block->{result}) {
        return $block->{result}->($block, @_);
    }
    
    # _result method.
    if ($block->can('_result')) {
        return $block->_result(@_);
    }
    
    return;
}

# default _parse.
sub _parse {
    return 1;
}

# default _result.
sub _result {
    return '';
}

# remove empty content items.
sub remove_blank {
    my $block = shift;
    my @new;
    foreach my $item (@{$block->{content}}) {
        my $_item = $item; $_item =~ s/^\s*//g; $_item =~ s/\s*$//g;
        push @new, $item if length $_item;
    }
    $block->{content} = \@new;
}

1
