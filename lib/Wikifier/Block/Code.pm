# Copyright (c) 2017, Mitchell Cooper
#
# code blocks display a block of code or other unformatted text.
#
package Wikifier::Block::Code;

use warnings;
use strict;

our %block_types = (code => {
    html => \&code_html
});

sub code_html {
    my ($block, $page, $el) = @_;
    $el->configure(
        type      => 'pre',
        no_indent => 1,
        classes   => [ '!prettyprint' ],
        content   => [ @{ $block->{content} } ] # copy
    );
}

__PACKAGE__
