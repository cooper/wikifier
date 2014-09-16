#
# Copyright (c) 2014, Mitchell Cooper
#
# insert raw HTML
#
package Wikifier::Block::Html;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    html   => { html => sub { html_html(0, @_) } },
    format => { html => sub { html_html(1, @_) } }
);

sub html_html {
    my ($format, $block, $page, $el) = @_;
    foreach my $item (@{ $block->{content} }) {
        $item = $item->html($page) if blessed $item;
        $item = $page->parse_formatted_text($item, 1) if $format;
        $el->add($item);
    }
}

__PACKAGE__
