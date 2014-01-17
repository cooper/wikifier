#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# paragraph blocks represent a paragraph of text.
#
package Wikifier::Block::Paragraph;

use warnings;
use strict;

our %block_types = ( paragraph => { html => \&paragraph_html } );

sub paragraph_html {
    my ($block, $page) = @_;

    # Parse formatting.
    my $html = Wikifier::Utilities::indent($block->{content}[0]);
    $html = $page->parse_formatted_text($html);

    return "<p class=\"wiki-paragraph\">\n$html\n</p>\n";
}

__PACKAGE__
