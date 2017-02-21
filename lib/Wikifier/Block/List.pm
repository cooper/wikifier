# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Block::List;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(trim truncate_hr fix_value append_value);

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

    # get human readable values
    my $get_hr; $get_hr = sub {
        my @stuff = map {
            my $thing = ref $_ ? $_ : trim($_);
            my $res   =
                ref $thing eq 'ARRAY'                       ?
                    join(' ', map $get_hr->($_), @$thing)   :
                !length $thing                              ?
                    undef                                   :
                blessed $thing                              ?
                    $thing->hr_desc                         :
                q(').truncate_hr($thing, 30).q(');
            $res;
        } @_;
        return wantarray ? (@stuff) : $stuff[0];
    };

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
    $pos->{line} = $block->{line};
    my $value_text = $get_hr->($value);

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

        # if this is an arrayref, it's a mixture of blocks and text
        my @items = ref $value eq 'ARRAY' ? @$value : $value;

        # handle each item
        my @new_value;
        foreach my $item (@items) {

            # parse formatted text
            if (!blessed $item && !$block->{no_format_values}) {
                $item = $page->parse_formatted_text($item, pos => $_->{pos});
            }

            # convert block to element.
            # this has to come after the above since ->parse_formatted_text()
            # might return a block.
            if (blessed $item) {
                my $their_el = $item->html($page);
                $item = $their_el || "$item";
            }

            push @new_value, $item;
        }

        # overwrite the value in list_array
        # add to new list_array_values
        $value = \@new_value;
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
