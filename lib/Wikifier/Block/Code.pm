# Copyright (c) 2017, Mitchell Cooper
#
# code blocks display a block of code or other unformatted text.
#
package Wikifier::Block::Code;

use warnings;
use strict;

our %block_types = (code => {
    html  => \&code_html,
    title => 1
});

sub code_html {
    my ($block, $page, $el) = @_;
    my @classes = 'code';
    
    my $lang = length $block->name ? $block->name : $block->meta('lang');
    if (length $lang) {
        push @classes, '!prettyprint';
        push @classes, "!lang-$lang";
    }
    
    # fetch text nodes and add them content as scalar refs.
    # this tells the HTML generator to run encode_entities() on it.
    my @text;
    foreach my $item ($block->content_visible) {
        next if ref $item;
        push @text, \$item;
    }
    
    $el->configure(
        type      => 'pre',
        no_indent => 1,
        classes   => \@classes,
        content   => \@text
    );
}

__PACKAGE__
