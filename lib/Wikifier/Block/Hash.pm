#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# hash provides a subclass for key:value-based blocks.
#
package Wikifier::Block::Hash;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block';

use Scalar::Util 'blessed';
use Carp;

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'hash';
    $opts{hash_array} = [];
    return $class->SUPER::new(%opts);
}

# parse key:value pairs.
sub _parse {
    my $block = shift;
    my ($key, $value, $in_value, %values) = (q.., q..);
    
    # for each content item...
    ITEM: foreach my $item (@{$block->{content}}) {
    
        # if blessed, it's a block value, such as an image.
        if (blessed($item)) {
        
            # if there is no key, give up.
            if (!length $key) {
                croak "no key for block value in hash-based block of type $$block{type} ($value)";
                return;
            }
            
            # set the value to the block item itself.
            $value = $values{$key} = $item;
            
            # call the item's ->parse() to ensure its
            # resulting values are ready when we need them.
            $item->parse();

            next ITEM;
        }
        
        # for each character in this string...
        for (split //, $item) {
        
            my $char = $_;
            
            # the first colon indicates that we're beginning a value.
            when (':') {
                
                # if there is no key, give up.
                if (!length $key) {
                    croak "no key for text value in hash-based block ($value)";
                    return;
                }
                
                # if we're already in a value, this colon belongs to the value.
                continue if $in_value; # to default.
                
                $in_value = 1;
            }
            
            # a semicolon indicates the termination of a pair.
            when (';') {
            
                # remove spaces from key and value.
                $key   =~ s/(^\s*)|(\s*$)//g; my $key_title = $key;
                $value =~ s/(^\s*)|(\s*$)//g unless blessed $value;
           
                # if this key exists, rename it to the next available <name>_key_<n>.
                while (exists $values{$key}) {
                    my ($key_name, $key_number) = split '_key_', $key;
                    if (!defined $key_number) {
                        $key = "${key}_key_2";
                        next;
                    }
                    $key_number++;
                    $key = "${key_name}_key_$key_number";
                }
                
                # store the value.
                $values{$key} = $value;
                push @{$block->{hash_array}}, [$key_title, $value];
            
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
            }
            
        } # end of character loop.

    } # end of item loop.
    
    # append/overwrite values found in this parser.
    my %hash = $block->{hash} ? %{$block->{hash}} : ();
    @hash{ keys %values } = values %values;
    
    # reassign the hash.
    $block->{hash} = \%hash;
    
    return 1;
}

1
