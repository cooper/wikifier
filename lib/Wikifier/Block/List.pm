# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Block::List;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(
    trim fix_value append_value html_value hr_value
);

our %block_types = (list => {
    init   => \&list_init,
    parse  => \&list_parse,
    html   => \&list_html
});


sub list_init {
    my $block = shift;
    $block->{list_array} = [];
    $block->{list_array_values} = [];
}

# parse a list.
sub list_parse {
    my ($block, $page) = @_;
    my ($value, $pos);

    # for each content item...
    ITEM: foreach ($block->content_visible_pos) {
        (my $item, $pos) = @$_;

        # if blessed, it's a block value, such as an image.
        if (blessed $item) {
            append_value $value, $item;
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

                # fix the value.
                fix_value $value;

                # store the value.
                push @{ $block->{list_array} }, {
                    value => $value,        # value
                    pos   => $pos           # position
                };
                push @{ $block->{list_array_values} }, $value;

                # reset status.
                undef $value;
            }

            # any other character
            else {
                append_value $value, $char;
                $escaped = 0;
            }

            # increment line position maybe
            $pos->{line}++ if $char eq "\n";

        }   # end of character loop.
    }       # end of item loop.

    # warning stuff
    $pos->{line} ||= $block->{line};
    my $value_text = hr_value $value;

    # unterminated value warning
    $block->warning($pos, "Value $value_text not terminated")
        if $value_text;

    return 1;
}

sub list_html {
    my ($block, $page, $el) = (shift, @_);
    my @new;

    # start with a ul.
    $el->configure(type => 'ul');

    # append each item.
    foreach ($block->list_array) {
        my $value = $_->{value};

        # prepare value for inclusion in HTML element
        html_value $value, $_->{pos}, $page, !$block->{no_format_values};

        # overwrite the value in list_array
        # add to new list_array_values
        $_->{value} = $value;
        push @new, $value;

        $el->create_child(
            type       => 'li',
            class      => 'list-item',
            content    => $value
        );
    }
    $block->{list_array_values} = \@new;
}

sub to_data {
    my $list = shift;
    return $list->{list_array_values};
}

sub list_array          { @{ shift->{list_array}        } }
sub list_array_values   { @{ shift->{list_array_values} } }

__PACKAGE__
