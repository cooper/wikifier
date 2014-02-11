#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# paragraph blocks represent a paragraph of text.
#
package Wikifier::Block::Paragraph;

use warnings;
use strict;

use Scalar::Util 'blessed';
use HTML::Entities qw(encode_entities);

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
    my ($clear, $block, $page, $el) = @_;
    $el->configure(type => 'p');
    $el->add_class('clear') if $clear;
    
    # parse formatting.
    my $html = Wikifier::Utilities::indent($block->{content}[0]);
    $html    = $page->parse_formatted_text($html);

    foreach my $item (@{ $block->{content} }) {
        next if blessed $item; # paragraphs cannot currently contain anything.
        $el->add(encode_entities($item));
    }

}

__PACKAGE__
