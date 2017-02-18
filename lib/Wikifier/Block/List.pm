# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Block::List;

use warnings;
use strict;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(trim truncate_hr);

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
    my $get_hr = sub {
        my @stuff = map {
            my $thing = blessed $_ ? $_ : trim($_);
            my $res   =
                !length $thing      ?
                undef               :
                blessed $thing      ?
                $thing->hr_desc     :
                q(').truncate_hr($thing, 30).q(');
            $res;
        } @_;
        return wantarray ? (@stuff) : $stuff[0];
    };

    # add a block or text to the value
    $append_value = sub {
        my $append = shift;

        # nothing
        return if !defined $append;

        # first item
        if (ref $value ne 'ARRAY' || !@$value) {
            $value = [ $append ];
            return;
        }

        # if the last element or the append element are refs, push
        my $last = \$value->[-1];
        if (ref $$last || ref $append) {
            push @$value, $append;
            return;
        }

        # otherwise, append as text
        $$last .= $append;
    };

    # fix the value
    $fix_value = sub {
        my @new;
        foreach my $item (@$value) {
        if (!blessed $item) {
            $item =~ s/(^\s*)|(\s*$)//g;

            # special value -no-format-values;
            if ($item eq '-no-format-values') {
                $block->warning($pos, 'Redundant -no-format-values')
                    if $block->{no_format_values}++;
                $item = '';
                next CHAR;
            }
        }
        $value = \@new;
        $value = $new[0] if @new == 1;
    };

    # for each content item...
    ITEM: foreach ($block->content_visible_pos) {
        (my $item, $pos) = @$_;

        # if blessed, it's a block value, such as an image.
        if (blessed($item)) {
            $append_value->($item);
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
                $fix_value->();

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
                $append_value->($char);
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

        # convert block to element
        if (blessed $value) {
            my $their_el = $value->html($page);
            $value = $their_el || "$value";
        }

        # parse formatted text
        elsif (!$block->{no_format_values}) {
            $value = $page->parse_formatted_text($value, pos => $_->{pos});
            if (blessed $value) {
                my $their_el = $value->html($page);
                $value = $their_el || "$value";
            }
        }

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
