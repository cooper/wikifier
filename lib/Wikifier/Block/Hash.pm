#
# Copyright (c) 2014, Mitchell Cooper
#
# hash provides a subclass for key:value-based blocks.
#
package Wikifier::Block::Hash;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(L);

our %block_types = (
    hash => {
        init  => \&hash_init,
        parse => \&hash_parse,
        html  => \&hash_html
    }
);

sub hash_init {
    my $block = shift;
    $block->{hash_array} = [];
}

# parse key:value pairs.
sub hash_parse {
    my ($block, $page) = (shift, @_);
    my ($key, $value, $in_value, %values) = (q.., q..);

    # for each content item...
    ITEM: foreach my $item (@{ $block->{content} }) {

        # if blessed, it's a block value, such as an image.
        if (blessed($item)) {
            $item->parse(@_);
            $key = $item; # this will actually become the value,
                          # when we realize we don't have one
            next ITEM;
        }

        # for each character in this string...
        my $escaped; # true if the last was escape character
        my $i = 0;
        CHAR: for (split //, $item) { $i++;
            my $char = $_;

            # the first colon indicates that we're beginning a value.
            when (':') {

                # if we're already in a value, this colon belongs to the value.
                continue if $in_value; # to default.

                # this was escaped.
                continue if $escaped;

                # we're now inside the value.
                $in_value = 1;
            }

            when ("\\") {
                continue if $escaped; # this backslash was escaped.
                $escaped = 1;
            }

            # a semicolon indicates the termination of a pair.
            when (';') {

                # it was escaped.
                continue if $escaped;

                # if there's no key, it is something like:
                #   : value;
                my $key_title;
                if (!length $key) {
                    $key = "anon_$i";
                    undef $key_title;
                }

                # if there is a key but we weren't in the value,
                # it is something like:
                #   value;
                elsif (!$in_value) {
                    $value = $key;
                    $key = "anon_$i";
                    undef $key_title;
                }

                # otherwise, it's a normal key-value pair.
                # fix the key
                else {
                    $key = "$key" if blessed $key; # just in case
                    $key =~ s/(^\s*)|(\s*$)//g;
                    $key_title = $key;
                }

                # fix the value
                if (!blessed $value) {
                    $value =~ s/(^\s*)|(\s*$)//g;

                    # special value -no-format-values;
                    if ($value eq '-no-format-values') {
                        $block->{no_format_values}++;
                        $in_value = 0;
                        $key = $value = '';
                        next CHAR;
                    }
                }

                # if this key exists, rename it to the next available <key>_key_<n>.
                KEY: while (exists $values{$key}) {
                    my ($key_name, $key_number) = split '_key_', $key;
                    if (!defined $key_number) {
                        $key = "${key}_2";
                        next KEY;
                    }
                    $key_number++;
                    $key = "${key_name}_${key_number}";
                }

                # store the value.
                $values{$key} = $value;
                push @{ $block->{hash_array} }, [$key_title, $value, $key];

                # reset status.
                $in_value = 0;
                $key = $value = '';
            }

            # any other characters.
            default {
                $value  .= $char if  $in_value;
                $key    .= $char if !$in_value;
                $escaped = 0;
            }
        } # end of character loop.
    } # end of item loop.

    # append/overwrite values found in this parser.
    my %hash = $block->{hash} ? %{ $block->{hash} } : ();
    @hash{ keys %values } = values %values;

    # reassign the hash.
    $block->{hash} = \%hash;

    return 1;
}

sub hash_html {
    my ($block, $page) = (shift, @_);
    foreach (@{ $block->{hash_array} }) {
        my ($key_title, $value, $key) = @$_;
        if (blessed $value) {
            $value = $value->html($page)->generate;
        }
        elsif (!$block->{no_format_values}) {
            $value = $page->parse_formatted_text($value);
        }
        else {
            next;
        }
        $_->[1] = $value;
        $block->{hash}{$key} = $value;
    }
}

__PACKAGE__
