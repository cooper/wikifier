#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# paragraph blocks represent a paragraph of text.
#
package Wikifier::Block::Paragraph;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'paragraph';
    return $class->SUPER::new(%opts);
}

sub parse {
    my $block = shift;
    # there's not too much to parse in a paragraph of text.
    # formatting, etc. is handled later.
}

sub result {
    my ($block, $page) = @_;

    # Parse formatting.
    my $html = Wikifier::indent($block->{content}[0]);
    $html = $page->parse_formatted_text($html);

    return "<p>\n$html\n</p>\n";
}

1
