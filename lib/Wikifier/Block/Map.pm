# Copyright (c) 2016, Mitchell Cooper
#
# map provides a subclass for key:value-based blocks.
#
package Wikifier::Block::Map;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(L trim);

our %block_types = (
    map => {
        init  => \&map_init,
        parse => \&map_parse,
        html  => \&map_html,
        invis => 1
    },
    hash => {
        alias => 'map'
    }
);

sub map_init {
    my $block = shift;
    $block->{map_array} = [];
}

# parse key:value pairs.
sub map_parse {
    my ($block, $page) = (shift, @_);
    my ($pos, $key, $value, $in_value, %values) = (q.., q..);

    # for each content item...
    ITEM: foreach ($block->content_visible_pos) {
        (my $item, $pos) = @$_;
        $pos = { %$pos }; # copy because we are modifying it

        # if blessed, it's a block value, such as an image.
        if (blessed($item)) {
            # $item->parse(@_);
            $key   = $item if !$in_value; # this will actually become the value,
            $value = $item if  $in_value; # when we realize we don't have one
            next ITEM;
        }

        # for each character in this string...
        my $escaped; # true if the last was escape character
        my $i = 0;
        CHAR: for (split //, $item) { $i++;
            my $char = $_;

            # the first colon indicates that we're beginning a value.
            if ($char eq ':' && !$in_value && !$escaped) {
                $in_value++;
            }

            # escape
            elsif ($char eq "\\" && !$escaped) {
                $escaped++;
            }

            # a semicolon indicates the termination of a pair.
            elsif ($char eq ';' && !$escaped) {

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
                    $block->warning($pos,
                        "Standalone text should be prefixed with ':'"
                    ) unless blessed $key;
                    $value = $key;
                    $key = "anon_$i";
                    undef $key_title;
                }

                # otherwise, it's a normal key-value pair.
                # fix the key
                else {
                    $key = "$key" if blessed $key; # just in case
                    $key = trim($key);
                    $key_title = $key;
                }

                # fix the value
                my $is_block = blessed $value;
                if (!$is_block) {
                    $value = trim($value);

                    # special value -no-format-values;
                    if ($value eq '-no-format-values') {
                        $block->warning($pos, 'Redundant -no-format-values')
                            if $block->{no_format_values}++;
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
                push @{ $block->{map_array} }, [
                    $key_title,     # displayed key
                    $value,         # value, at this stage text or block
                    $key,           # actual hash key
                    $is_block       # true if value originally was a block
                ];

                # keys spanning multiple lines are fishy
                $block->warning($pos, "Suspicious key '$key'") if $key =~ m/\n/;

                # reset status.
                $in_value = 0;
                $key = $value = '';
            }

            # any other characters.
            # TODO: produce a warning if $key or $value is blessed and we are
            # trying to append it. they likely forgot a semicolon after a block.
            else {
                $escaped = 0;
                $value  .= $char if  $in_value;
                $key    .= $char if !$in_value;
            }

            $pos->{line}++ if $char eq "\n";
        } # end of character loop.
    } # end of item loop.

    my $warn;
    $key = trim($key); $value = trim($value);
    $warn = "Stray text '$key' ignored"     if length $key;
    $warn = "Value '$value' not terminated" if length $value;
    $block->warning($pos, $warn) if $warn;

    # append/overwrite values found in this parser.
    my %hash = $block->{map} ? %{ $block->{map} } : ();
    @hash{ keys %values } = values %values;

    # reassign the hash.
    $block->{map} = \%hash;

    return 1;
}

sub map_html {
    my ($block, $page) = (shift, @_);
    foreach (@{ $block->{map_array} }) {
        my ($key_title, $value, $key) = @$_;
        if (blessed $value) {
            my $their_el = $value->html($page);
            $value = $their_el ? $their_el->generate : "$value";
        }
        elsif (!$block->{no_format_values}) {
            $value = $page->parse_formatted_text($value);
        }
        else {
            next;
        }
        $_->[1] = $value; # overwrite the block value with HTML
        $block->{map}{$key} = $value;
    }
}

__PACKAGE__
