#
# Copyright (c) 2014, Mitchell Cooper
#
# code blocks display a block of code or other unformatted text. 
#
package Wikifier::Block::Code;

use warnings;
use strict;

our %block_types = (
    code => {
        html => \&code_html
    }
);

sub code_html {
    my ($block, $page, $el) = @_;
    $el->configure(
        type    => 'pre',
        class   => 'code',
        content => $page->parse_formatted_text($block->{content}[0])
    );
}

1
