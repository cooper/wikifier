#
# Copyright (c) 2014, Mitchell Cooper
#
# hash provides a subclass for key:value-based blocks.
#
package Wikifier::Block::Hash;

use warnings;
use strict;
use 5.010;

use Scalar::Util 'blessed';

our %block_types = (
    hash => {
        init  => \&hash_init,
        parse => \&hash_parse
    }
);

sub hash_init {
    my $block = shift;
    $block->{hash_array} = [];
}

# parse key:value pairs.
sub hash_parse {
    my $block = shift;
    my ($key, $value, $in_value, %values) = (q.., q..);
    
    # for each content item...
    ITEM: foreach my $item (@{ $block->{content} }) {
        
        # if blessed, it's a block value, such as an image.
        if (blessed($item)) {

            # set the value to the block item itself.
            $value = $values{$key} = $item;

            next ITEM;
        }
        
        # for each character in this string...
        my $escaped; # true if the last was escape character
        my $i = 0;
        for (split //, $item) { $i++;
            my $char = $_;
            
            # the first colon indicates that we're beginning a value.
            when (':') {
                
                # if there is no key, give up.
                if (!length $key) {
                    Wikifier::l("No key for text value in hash-based block ($value)");
                    $key = "Item $i";
                }
                
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

                # remove spaces from key and value.
                $key   =~ s/(^\s*)|(\s*$)//g; my $key_title = $key;
                $value =~ s/(^\s*)|(\s*$)//g unless blessed $value;

                # no key.
                if (!$key) {
                    $key       = "anon_$i";
                    $key_title = undef;
                }
           
                # if this key exists, rename it to the next available <name>_key_<n>.
                while (exists $values{$key}) {
                    my ($key_name, $key_number) = split '_key_', $key;
                    if (!defined $key_number) {
                        $key = "${key}_2";
                        next;
                    }
                    $key_number++;
                    $key = "${key_name}_$key_number";
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
            
                # if we're in a value, append to the value.
                if ($in_value) {
                    $value .= $char;
                }
                
                # otherwise, append to the key.
                else {
                    $key .= $char;
                }
                
                # pretty simple stuff.
                
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

__PACKAGE__
