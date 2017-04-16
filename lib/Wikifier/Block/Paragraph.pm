# Copyright (c) 2017, Mitchell Cooper
#
# paragraph blocks represent a paragraph of text.
#
package Wikifier::Block::Paragraph;

use warnings;
use strict;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(trim);

our %block_types = (
    paragraph => {
        html => \&paragraph_html
    },
    p => {
        alias => 'paragraph'
    }
);

sub paragraph_html {
    my ($block, $page, $el) = @_;
    $el->configure(type => 'p');
    LINE: foreach ($block->content_visible_pos) {
        my ($item, $pos) = @$_;

        # this is blessed, so it's a block.
        # adopt this element.
        if (blessed $item) {
            $el->add($item->html($page));
            next;
        }

        # trim after formatting so that position is accurate
        my $line = trim($page->parse_formatted_text($item, pos => $pos));

        # skip if no length is left
        $pos->{line}++;
        next LINE unless length $line;

        $el->add(\$line);
    }
}

__PACKAGE__
