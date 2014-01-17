#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# code blocks display a block of code or other unformatted text. 
#
package Wikifier::Block::Code;

use warnings;
use strict;
use feature qw(switch);

our %block_types = (
    code => {
        html => \&code_html
    }
);

sub code_html {
    my ($block, $page) = @_;
    my $code = $block->{content}[0];
    return "<pre class=\"wiki-code\">$code</pre>\n";
}

1
