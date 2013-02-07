#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# sections are containers for paragraphs, image boxes, etc., each with a title.
# the one exception is the introductory section, which has no title and does not display
# at all in the article's table of contents.
#
package Wikifier::Block::Section;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block::Container';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'section';
    return $class->SUPER::new(%opts);
}

sub parse {
    my $block = shift;
    $block->SUPER::parse();
}

1
