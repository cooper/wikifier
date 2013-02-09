#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# code blocks display a block of code or other unformatted text. 
#
package Wikifier::Block::Code;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'code';
    return $class->SUPER::new(%opts);
}

sub parse {
    my $block = shift;
    # there's not too much to parse in a paragraph of text.
    # formatting, etc. is handled later.
}

sub result {
    my ($block, $page) = @_;
    my $code = $block->{content}[0];
    return "<pre class=\"wiki-code\"><code>\n$code\n</code></pre>\n";
}

1
