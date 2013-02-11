#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# references{} displays a list of citations and sources.
#
package Wikifier::Block::References;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block::Hash';

use Scalar::Util 'blessed';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'references';
    return $class->SUPER::new(%opts);
}

sub result {
    my ($block, $page) = (shift, @_);
    my $string = qq{<ul class="wiki-references">\n};
    my @pairs  = (@{$block->{hash_array}}, @{$page->{references}});
    
    # append each reference.
    foreach my $pair (@pairs) {
        my ($key, $value) = @$pair;
        
        # special pair - ignore it.
        if (substr($key, 0, 1) eq '-') {
            next;
        }
        
        # value is a block. generate the HTML for it.
        if (blessed $value) {
            $value = $value->result(@_);
        }
        
        # Parse formatting in the value.
        else {
            $value = $page->parse_formatted_text($value);
        }
        
        # append table row.
        $string .= <<END;
    <li class="wiki-ref-item"><a class="wiki-ref-anchor" name="wiki-ref-$key">$key. $value</a></li>        
END
    }
    
    $string .= qq{</ul>\n};
    return $string;
}

1
