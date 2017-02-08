# Copyright (c) 2017, Mitchell Cooper
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
    foreach ($block->content_visible_pos) {
        my ($item, $pos) = @$_;
        if (blessed $item) {
            $item = $item->html($page);
        }
        elsif ($format) {
            $item = $page->parse_formatted_text($item,
                no_entities => 1,
                pos => $pos
            );
        }
        $el->add($item);
    }
}

__PACKAGE__
