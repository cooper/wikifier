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
    return $class->SUPER::new(%opts);
}

# parse key:value pairs.
sub parse {
    my $block = shift;
    my ($key, $value, $in_value, %values) = (q.., q..);
    
    # for each content item...
    foreach my $item (@{$block->{content}}) {
    
        # if blessed, it's a block value, such as an image.
        if (blessed($item)) {
        
            # if there is no key, give up.
            if (!length $key) {
                croak "no key for block value in hash-based block";
                return;
            }
            
            # remove spaces.
            $key =~ s/(^\s*)|(\s*$)//g;
            
            # set the value to the block item itself.
            $values{$key} = $item;
            
            next;
        }
        
        # for each character in this string...
        for (split //, $item) {
        
            my $char = $_;
            
            # the first colon indicates that we're beginning a value.
            when (':') {
                
                # if there is no key, give up.
                if (!length $key) {
                    croak "no key for text value in hash-based block";
                    return;
                }
                
                # if we're already in a value, this colon belongs to the value.
                continue if $in_value; # to default.
                
                $in_value = 1;
            }
            
            # a semicolon indicates the termination of a pair.
            when (';') {
            
                # remove spaces.
                $key   =~ s/(^\s*)|(\s*$)//g;
                $value =~ s/(^\s*)|(\s*$)//g;
                
                # store the value.
                $values{$key} = $value if !$values{$key};
                
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
