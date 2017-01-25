#
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

use Scalar::Util qw(blessed weaken);

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
#   wikifier:   the wikifier object.
#
# For subclasses, the type is provided automatically.
# This should rarely be used directly; use $wikifier->create_block().
#
sub new {
    my ($class, %opts) = @_;
    $opts{content} ||= [];
    $opts{type} = lc $opts{type};
    my $block = bless \%opts, $class;

    # weaken reference to wikifier.
    weaken($block->{wikifier}) if $block->{wikifier};

    return $block;
}

#############
### PARSE ###
#############

# parse the contents.
sub parse {
    my $block = shift;
    my $type  = $block->{type};

    # parse this block.
    $block->{parse_done} = {};
    $block->_parse($type, @_);
    delete $block->{parse_done};

    # parse child blocks.
    foreach my $block (@{ $block->{content} }) {
        next unless blessed $block;
        $block->parse(@_);
    }

}

# run the base's parse() now instead of afterward.
# this is similar to the former method of calling
# SUPER::parse() at the beginning of a parse().
sub parse_base {
    my $block = shift;
    my $type  = $Wikifier::BlockManager::block_types{ $block->{type} }{base};
    $block->_parse($type, @_);
}

# do not call directly.
sub _parse {
    my ($block, $type) = (shift, shift);

    # parse the block hereditarily.
    while ($type) {
        my $type_opts = $Wikifier::BlockManager::block_types{$type};
        if ($type_opts->{parse} && !$block->{parse_done}{$type}) {
            $type_opts->{parse}->($block, @_);
            $block->{parse_done}{$type} = 1;
        }
        $type = $type_opts->{base};
    }

}

############
### HTML ###
############

# HTML contents.
sub html {
    my $block = shift;
    my $type  = $block->{type};
    $block->remove_blank;

    # create the element.
    $block->{element} = Wikifier::Element->new(
        class => $block->{type},
        ids   => $block->{wikifier}{element_identifiers} ||= {}
    );

    # generate this block.
    $block->{html_done} = {};
    $block->_html($type, @_);
    delete $block->{html_done};

    # do child blocks that haven't been done.
    foreach my $block (@{ $block->{content} }) {
        next unless blessed $block;
        next if $block->{called_html};
        $block->html(@_);
    }

    # add classes from the parser.
    my @classes = @{ delete $block->{classes} || [] };
    $block->{element}->add_class("class-$_") foreach @classes;

    return $block->{element};
}

# run the base's html() now instead of afterward.
# this is similar to the former method of calling
# SUPER::html() at the beginning of a html().
sub html_base {
    my $block = shift;
    my $type  = $Wikifier::BlockManager::block_types{ $block->{type} }{base};
    $block->_html($type, @_);
}

# do not call directly.
sub _html {
    my ($block, $type) = (shift, shift);

    # generate the block hereditarily.
    while ($type) {
        my $type_opts = $Wikifier::BlockManager::block_types{$type};
        if ($type_opts->{html} && !$block->{html_done}{$type}) {
            $type_opts->{html}->($block, @_, $block->{element});
            $block->{html_done}{$type} = 1;
        }
        $type = $type_opts->{base};
        $block->{called_html}++;
    }

}

#############
### OTHER ###
#############

# remove empty content items.
sub remove_blank {
    my $block = shift;
    my @new;
    foreach my $item (@{ $block->{content} }) {
        push @new, $item and next if blessed $item;
        my $trimmed = Wikifier::Utilities::trim($item);
        push @new, $item if length $trimmed;
    }
    $block->{content} = \@new;
}

1
