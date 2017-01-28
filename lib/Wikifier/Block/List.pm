#
# Copyright (c) 2014, Mitchell Cooper
#
package Wikifier::Block::List;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (list => {
    init   => \&list_init,
    parse  => \&list_parse,
    html   => \&list_html
});


sub list_init {
    my $block = shift;
    $block->{list_array} = [];
}

# parse a list.
sub list_parse {
    my ($block, $page) = @_;
    my $value = '';

    # for each content item...
    ITEM: foreach my $item ($block->content_visible) {

        # if blessed, it's a block value, such as an image.
        if (blessed($item)) {

            # set the value to the block item itself.
            $value = $item;

            next ITEM;
        }

        # for each character in this string...
        my $escaped; # true if the last was escape character
        my $i = 0;

        CHAR: for (split //, $item) { $i++;
            my $char = $_;

            if ($char eq "\\" && !$escaped) {
                $escaped = 1;
            }

            # a semicolon indicates the termination of a pair.
            elsif ($char eq ';' && !$escaped) {

                # fix the value
                if (!blessed $value) {
                    $value =~ s/(^\s*)|(\s*$)//g;

                    # special value -no-format-values;
                    if ($value eq '-no-format-values') {
                        $block->{no_format_values}++;
                        $value = '';
                        next CHAR;
                    }
                }

                # store the value.
                push @{ $block->{list_array} }, $value;

                # reset status.
                $value = '';
            }

            # any other characters.
            else {
                $value .= $char;
                $escaped = 0;
            }

        }   # end of character loop.
    }       # end of item loop.

    return 1;
}

sub list_html {
    my ($block, $page, $el) = (shift, @_);
    my @new;

    # start with a ul.
    $el->{type} = 'ul';

    # append each item.
    foreach my $value (@{ $block->{list_array} }) {
        if (blessed $value) {
            my $their_el = $value->html($page);
            $value = $their_el ? $their_el->generate : "$value";
        }
        elsif (!$block->{no_format_values}) {
            $value = $page->parse_formatted_text($value);
        }
        push @new, $value;

        $el->create_child(
            type       => 'li',
            class      => 'list-item',
            content    => $value
        );
    }

    $block->{list_array} = \@new;
}

__PACKAGE__
