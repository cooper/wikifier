#
# Copyright (c) 2014, Mitchell Cooper
#
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
}

# parse a list.
sub list_parse {
    my ($block, $page) = @_;
    my ($value, $pos, $ow_value, $ap_value) = '';

    # get human readable values
    my $get_hr = sub {
        my @stuff = map {
            my $thing = blessed $_ ? $_ : trim($_);
            my $res   =
                !length $thing      ?
                undef               :
                blessed $thing      ?
                "$$thing{type}\{}"  :
                q(').truncate_hr($thing, 30).q(');
            $res;
        } @_;
        return wantarray ? (@stuff) : $stuff[0];
    };

    # check if we have bad values and produce warnings
    my $warn_bad_maybe = sub {

        # tried to append an object value
        if ($ap_value) {
            my $ap_value_text = $get_hr->($ap_value);
            $block->warning($pos, "Stray text after $ap_value_text ignored");
            undef $ap_value;
        }

        # overwrote a value
        if ($ow_value) {
            my ($old, $new) = $get_hr->(@$ow_value);
            $block->warning($pos, "Overwrote value $old with $new");
            undef $ow_value;
        }
    };

    # for each content item...
    ITEM: foreach ($block->content_visible_pos) {
        (my $item, $pos) = @$_;

        # if blessed, it's a block value, such as an image.
        if (blessed($item)) {

            # set the value to the block item itself.
            $ow_value = [ $value, $item ]
                if length trim($value);
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
                        $block->warning($pos, 'Redundant -no-format-values')
                            if $block->{no_format_values}++;
                        $value = '';
                        next CHAR;
                    }
                }

                # store the value.
                $warn_bad_maybe->();
                push @{ $block->{list_array} }, $value;

                # reset status.
                $value = '';
            }

            # any other character
            else {
                if (blessed $value) {
                    $ap_value = $value unless $char =~ m/\s/;
                }
                else { $value .= $char }
                $escaped = 0;
            }

        }   # end of character loop.
    }       # end of item loop.

    $warn_bad_maybe->();
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
