#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# paragraph blocks represent a paragraph of text.
#
package Wikifier::Block::Paragraph;

use warnings;
use strict;

use Scalar::Util 'blessed';

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

    foreach my $item (@{ $block->{content} }) {
        next if blessed $item; # paragraphs cannot currently contain anything.
        
        # trim.
        my @items;
        foreach my $line (split "\n", $item) {
            $line = Wikifier::Utilities::trim($line);
            push @items, $line if length $line;
        }
        
        $el->add($page->parse_formatted_text(join "\n", @items));
    }

}

__PACKAGE__
