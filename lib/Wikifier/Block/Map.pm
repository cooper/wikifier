# Copyright (c) 2017, Mitchell Cooper
#
# map provides a subclass for key:value-based blocks.
#
package Wikifier::Block::Map;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(
    trim fix_value append_value html_value hr_value
);

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
    $block->{map_hash}  = {};
    $block->{map_array} = [];
}

# parse key:value pairs.
sub map_parse {
    my ($block, $page) = (shift, @_);
    my (
        $key,       # key
        $value,     # value
        $pos,       # position
        $in_value,  # true if in value (between : and ;)
        $ap_key,    # an object which we tried to append key text to
        $ow_key,    # a key we overwrote with a block
        %values     # new hash values
    ) = ('');

    # check if we have bad keys or values and produce warnings
    my $warn_bad_maybe = sub {
        my $key_text = hr_value $key;

        # keys spanning multiple lines are fishy
        if (!blessed $key && length $key_text && $key_text =~ m/\n/) {
            $block->warning($pos, "Suspicious key $key_text");
        }

        # tried to append an object key
        if ($ap_key) {
            my $ap_key_text = hr_value $ap_key;
            $block->warning($pos, "Stray text after $ap_key_text ignored");
            undef $ap_key;
        }

        # overwrote a key
        if ($ow_key) {
            my ($old, $new) = hr_value @$ow_key;
            $block->warning($pos, "Overwrote $old with $new");
            undef $ow_key;
        }
    };

    # for each content item...
    ITEM: foreach ($block->content_visible_pos) {
        (my $item, $pos) = @$_;

        # if blessed, it's a block value, such as an image.
        if (blessed $item) {
            if ($in_value) {
                append_value $value, $item;
            }
            else {
                $ow_key = [ $key, $item ]
                    if length trim($key);
                $key = $item;
            }
            $warn_bad_maybe->();
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
                    ) if !blessed $key && index(trim($key), '-');
                    $value = [ $key ];
                    $key = "anon_$i";
                    undef $key_title;
                }

                # otherwise, it's a normal key-value pair.
                # fix the key
                else {
                    $key = "$key" if blessed $key; # just in case
                    $key = trim($key);
                    $key_title = $key;
                    $key =~ s/\W/_/g;
                }

                # fix the value
                fix_value $value;
                my $is_block = blessed $value; # true if ONE block and no text

                # if this key exists, rename it to the next available <key>_key_<n>.
                KEY: while (exists $values{$key}) {
                    my ($key_name, $key_number) = reverse map scalar reverse,
                        split('_', reverse($key), 2);
                    if (!defined $key_number || $key_number =~ m/\D/) {
                        $key = "${key}_2";
                        next KEY;
                    }
                    $key_number++;
                    $key = "${key_name}_${key_number}";
                }

                # store the value.
                $values{$key} = $value;
                push @{ $block->{map_array} }, {
                    key_title   => $key_title,     # displayed key
                    value       => $value,         # value, text or block
                    key         => $key,           # actual hash key
                    is_block    => $is_block,      # true if value was a block
                    pos         => $pos            # position
                };

                # warn bad keys and values
                $warn_bad_maybe->();

                # reset status.
                $in_value = 0;
                $key = $value = '';
            }

            # any other character
            else {
                $escaped = 0;

                # this is part of the value
                if ($in_value) {
                    append_value $value, $char;
                }

                # this must be part of the key
                else {
                    if (blessed $key) {
                        $ap_key = $key unless $char =~ m/\s/;
                    }
                    else { $key .= $char }
                }
            }

            # increment line position maybe
            $pos->{line}++ if $char eq "\n";

        } # end of character loop.
    } # end of item loop.

    # warning stuff
    $warn_bad_maybe->();
    $pos->{line} ||= $block->{line};
    my ($key_text, $value_text) = hr_value $key, $value;

    # value warnings
    if ($value_text) {
        my $warn = "Value $value_text";
        $warn .= " for key $key_text" if length $key_text;
        $block->warning($pos, "$warn not terminated");
    }

    # key warnings come later because $key will always be set unless there was a
    # semicolon to terminate the pair
    elsif ($key_text) {
        $block->warning($pos, "Stray key $key_text ignored");
    }

    # append/overwrite values found in this parser.
    my %hash = $block->{map_hash} ? %{ $block->{map_hash} } : ();
    @hash{ keys %values } = values %values;

    # reassign the hash.
    $block->{map_hash} = \%hash;

    return 1;
}

sub map_html {
    my ($block, $page) = (shift, @_);
    foreach ($block->map_array) {
        my ($value, $key, $pos) = @$_{ qw(value key pos) };

        # prepare for inclusion in an HTML element
        html_value $value, $pos, $page, !$block->{no_format_values};

        # overwrite the old value
        $_->{value} = $value;
        $block->{map_hash}{$key} = $value;
    }
}

sub to_data {
    my $map = shift;
    return $map->{map_hash};
}

sub map_array { @{ shift->{map_array} } }
sub map_hash  { %{ shift->{map_hash}  } }

__PACKAGE__
