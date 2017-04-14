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
    my @classes = 'code';
    if (length(my $lang = $block->name)) {
        push @classes, '!prettyprint';
        push @classes, "!lang-$lang";
    }
    $el->configure(
        type      => 'pre',
        no_indent => 1,
        classes   => \@classes,
        content   => [ @{ $block->{content} } ] # copy
    );
}

__PACKAGE__
