#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# history blocks display a table of dates and important events associated with them.
#
package Wikifier::Block::History;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block::Hash';

use Scalar::Util 'blessed';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'infobox';
    return $class->SUPER::new(%opts);
}

sub result {
    my ($block, $page) = @_;
    my $string = "<div class=\"wiki-history\">\n";
    
    # start table.
    $string .= "    <table class=\"wiki-history-table\">\n";
    
    # append each pair.
    foreach my $pair (@{$block->{hash_array}}) {
        my ($key, $value) = @$pair;
        
        # special pair - ignore it.
        if (substr($key, 0, 1) eq '-') {
            next;
        }
        
        # value is a block. generate the HTML for it.
        if (blessed $value) {
            $value = $value->result();
        }
        
        # Parse formatting in the value.
        else {
            $value = $page->parse_formatted_text($value);
        }
        
        # append table row.
        $string .= <<END

        <tr class="wiki-history-pair">
            <td class="wiki-history-key">$key</td>
            <td class="wiki-history-value">$value</td>
        </tr>
        
END
;

    }
    
    $string .= "    </table>\n</div>\n";
    return $string;
}

1
