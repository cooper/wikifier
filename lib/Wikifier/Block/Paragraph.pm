#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# paragraph blocks represent a paragraph of text.
#
package Wikifier::Block::Paragraph;

use warnings;
use strict;

our %block_types = (
    paragraph => {
        html  => sub { paragraph_html(0, @_) },
        alias => 'p'
    },
    'paragraph-clear' => {
        html  => sub { paragraph_html(1, @_) },
        alias => 'p-clear'
    }
);

sub paragraph_html {
    my ($clear, $block, $page) = @_;

    # Parse formatting.
    my $html = Wikifier::Utilities::indent($block->{content}[0]);
    $html    = $page->parse_formatted_text($html);
    $clear   = $clear ? 'clear ' : '';
    
    return "<p class=\"${clear}wiki-paragraph\">\n$html\n</p>\n";
}

__PACKAGE__
