#
# Copyright (c) 2014, Mitchell Cooper
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
    TEXT: foreach ($block->content_text_pos) {
        my ($item, $pos) = @$_;
        LINE: foreach my $line (split "\n", $item) {

            # trim after formatting so that position is accurate
            $line = trim($page->parse_formatted_text($line, pos => $pos));

            # skip if no length is left
            $pos->{line}++;
            next LINE unless length $line;

            $el->add($line);
        }
    }
}

__PACKAGE__
