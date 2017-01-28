#
# Copyright (c) 2014, Mitchell Cooper
#
# paragraph blocks represent a paragraph of text.
#
package Wikifier::Block::Paragraph;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    paragraph => {
        html  => \&paragraph_html,
        alias => 'p'
    }
);

sub paragraph_html {
    my ($block, $page, $el) = @_;
    $el->configure(type => 'p');

    foreach my $item ($block->content) {
        next if blessed $item; # paragraphs cannot currently contain anything.

        # trim.
        my @items;
        foreach my $line (split "\n", $item) {
            $line = Wikifier::Utilities::trim($line);
            push @items, $line if length $line;
        }

        $el->add($page->parse_formatted_text(join "\n", @items));
    }
}

__PACKAGE__
