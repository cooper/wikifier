# Copyright (c) 2016, Mitchell Cooper
#
# Wikifier::Block represents a parsing block, such a section, paragraph,
# infobox, etc. All blocks have a parent besides the main block, which is an
# artificial block to serve as the parent of all top-level blocks.
#
# Wikifier::Block is subclassed by several specific types of blocks, each which
# provides its own specific functionality.
#
package Wikifier::Block;

use warnings;
use strict;

use Scalar::Util qw(blessed weaken);
use Wikifier::Utilities qw(L truncate_hr);

# Properties of blocks
#
#   parent      (required) parent block
#
#   type        (required) type of block, such as 'imagebox', 'paragraph', etc.
#
#   name        block title (text between '[' and ']' in source)
#
#   content     mixed array ref of text and child block objects within the block
#
#   current     parser state information, used for warnings and errors mostly
#
#   line        line position where block was opened by '{'
#
#   col         column position of the '{' character which opened the block
#
#   classes     array ref of classes (e.g., p.left.clear -> [left, clear])
#
#   closed      true if the block was closed by '}' (rather, # of times closed)
#
#   end_line    line position where block was closed by '}'
#
#   end_col     column position of the '}' character which closed the block
#
#
# Block type definitions
#
#   alias       (string) block type for which this block is an alias. if the
#               option is specified, all other options within the block typedef
#               are ignored; only the properties of the target are respected
#
#   base        (string) block type from which this block type inherits. if
#               specified, the base will be loaded automatically when necessary,
#               and this block type becomes a dependency of it. the base block
#               type may provide generic parsing or HTML generation which the
#               inheriting block type can utilize with ->parse_base() and
#               ->html_base()
#
#   init        (code reference) executed upon the creation of a block, before
#               its inner contents are parsed or any HTML is generated. this is
#               useful for setting up the initial state of a new block
#
#   parse       (code reference) executed when the block's contents should be
#               parsed. typically at this point the data within the block
#               delimeters '{' and '}' is extracted and/or validated.
#               passed ($block, $page)
#
#   html        (code reference) executed when block should prepare its HTML
#               element object in preparation for HTML generation.
#               passed ($block, $page, $element)
#
#   title       (boolean) if true, the block type accepts a title within the
#               '[' and ']' delimeters following the block type
#
#   invis       (boolean) if true, the block yields no HTML. an element object
#               will not be created. the block may still implement an 'html'
#               option, but the code will not be passed an element object. if
#               marked invisible, the block will be entiely ignored by anything
#               that iterates over the ->content_visible method
#
#   multi       (boolean) if true, the block type is capable of yielding more
#               than one element. the 'html' option will be passed an instance
#               of Wikifier::Elements instead of a Wikifier::Element. this
#               is only useful when the block type may produce more than one
#               element and wrapping them in the primary element is undesired
#

# create a new block.
# this should rarely be used directly; use $wikifier->create_block()
sub new {
    my ($class, %opts) = @_;
    $opts{content} ||= [];
    $opts{type} = lc $opts{type};
    return bless \%opts, $class;
}

#############
### PARSE ###
#############

# parse the contents.
sub parse {
    my $block = shift;
    my $type_ref = $block->{type_ref};
    return if $block->{did_parse}++;

    # parse this block.
    $block->_parse($type_ref, @_);

    # parse child blocks.
    foreach my $block ($block->content_blocks) {
        $block->parse(@_);
    }
}

# run the base's parse() now instead of afterward.
# this is similar to the former method of calling
# SUPER::parse() at the beginning of a parse().
sub parse_base {
    my $block = shift;
    my $base_ref = $block->{type_ref}{base_ref};
    if (!$base_ref) {
        L $block->hr_type.' called ->parse_base(), but it has no base';
        return;
    }
    $block->_parse($base_ref, @_);
}

# do not call directly.
sub _parse {
    my ($block, $type_ref) = splice @_, 0, 2;
    my $done = $block->{parse_done} ||= {};
    while ($type_ref) {
        if ($type_ref->{parse} && !$done->{ $type_ref->{type} }++) {
            $type_ref->{parse}($block, @_);
        }
        $type_ref = $type_ref->{base_ref};
    }
    delete $block->{parse_done};
}


############
### HTML ###
############

# HTML contents.
sub html {
    my $block = shift;
    my $type_ref = $block->{type_ref};
    return $block->element if $block->{did_html}++;

    # strip excess whitespace
    $block->remove_blank;

    # generate this block.
    $block->_html($type_ref, @_);

    # do child blocks. they will be skipped if already done.
    foreach my $block ($block->content_blocks) {
        $block->html(@_);
    }

    # add classes from the parser.
    if ($block->element) {
        my @classes = @{ delete $block->{classes} || [] };
        $block->element->add_class("class-$_") foreach @classes;
    }

    return $block->element; # may be undef
}

# run the base's html() now instead of afterward.
# this is similar to the former method of calling
# SUPER::html() at the beginning of a html().
sub html_base {
    my $block = shift;
    my $base_ref = $block->{type_ref}{base_ref};
    if (!$base_ref) {
        L $block->hr_type.' called ->html_base(), but it has no base';
        return;
    }
    $block->_html($base_ref, @_);
}

# do not call directly.
sub _html {
    my ($block, $type_ref) = splice @_, 0, 2;
    my $done = $block->{html_done} ||= {};
    my $c    = $block->{current};
    my $el   = $block->{element} ||= do {
        my $el;

        # block with multiple elements
        if ($type_ref->{multi}) {
            $el = Wikifier::Elements->new;
        }

        # normal element
        elsif (!$type_ref->{invis}) {
            $el = Wikifier::Element->new(class => $block->type);
        }

        $el;
    };

    while ($type_ref) {
        @$c{ qw(line col) } = @$block{ qw(line col) };
        if ($type_ref->{html} && !$done->{ $type_ref->{type} }++) {
            $type_ref->{html}($block, @_, $el);
        }
        $type_ref = $type_ref->{base_ref};
    }
    delete $block->{html_done};
}

########################
### FETCHING CONTENT ###
########################

# returns all content. this is a list of mixed strings and blocks.
sub content {
    return @{ shift->{content} };
}

# same as ->content except it skips blocks that don't produce HTML.
sub content_visible {
    return grep { !blessed $_ || !$_->{type_ref}{invis} } shift->content;
}

# returns only child blocks, ignoring text content.
sub content_blocks {
    return grep { blessed $_ } shift->content;
}

# returns only text content, ignoring child blocks.
sub content_text {
    return grep { !blessed $_ } shift->content;
}

# returns all content. this is a list of mixed strings and blocks.
sub content_pos {
    my $block   = shift;
    my @content = $block->content;
    my @content_pos;
    for (0..$#content) {
        push @content_pos, [ $content[$_], $block->{position}[$_] ];
    }
    return @content_pos;
}

# same as ->content except it skips blocks that don't produce HTML.
sub content_visible_pos {
    return grep {
        !blessed $_->[0] || !$_->[0]{type_ref}{invis}
    } shift->content_pos;
}

# returns only child blocks, ignoring text content.
sub content_blocks_pos {
    return grep { blessed $_->[0] } shift->content_pos;
}

# returns only text content, ignoring child blocks.
sub content_text_pos {
    return grep { !blessed $_->[0] } shift->content_pos;
}

#############
### OTHER ###
#############

sub element { shift->{element}  }
sub parent  { shift->{parent}   }
sub type    { shift->{type}     }
sub name    { shift->{name}     }

# find the first parent of a type
sub first_parent {
    my ($block, $type) = @_;
    while ($block = $block->parent) {
        return $block if $block->type eq $type;
    }
    return;
}

# type{}
sub hr_type {
    my $block = shift;
    return "$$block{type}\{}";
}

# this is for human-readable version
sub to_desc {
    my $block = shift;
    my $title = truncate_hr($block->name, 30);
       $title = length $title ? "[$title]" : '';
    return "$$block{type}$title\{}";
}

# this is for the variable to html in [@some_var]
sub generate {
    my $block = shift;
    return $block->element->generate if $block->element;
    $block->warning(
        'Tried to display ' . $block->hr_type .
        ' which has no element associated with it'
    );
    return $block->hr_type;
}

# produce a parser warning
sub warning {
    my ($block, $pos, $warn) = @_;
    if (!defined $warn) {
        $warn = $pos;
        $pos  = $block;
    }
    my $c = $block->{current} or return;
    $c->{temp_line} = $pos->{line};
    $c->{temp_col}  = $pos->{col};
    $c->warning($warn);
}

# remove empty content items.
sub remove_blank {
    my $block = shift;
    my @new;
    foreach my $item ($block->content) {
        push @new, $item and next if blessed $item;
        my $trimmed = Wikifier::Utilities::trim($item);
        push @new, $item if length $trimmed;
    }
    $block->{content} = \@new;
}

1
