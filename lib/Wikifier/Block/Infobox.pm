#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# infoboxes display a titled box with an image and table of information.
#
package Wikifier::Block::Infobox;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    infobox => {
        base => 'hash',
        html => \&infobox_html
    }
);

sub infobox_html {
    my ($block, $page) = (shift, @_);
    my $string = "<div class=\"wiki-infobox\">\n";
    
    # display the title if it exists.
    if (length $block->{name}) {
        $string .= "    <div class=\"wiki-infobox-title\">$$block{name}</div>\n";
    }
    
    # start table.
    $string .= "    <table class=\"wiki-infobox-table\">\n";
    
    # append each pair.
    foreach my $pair (@{$block->{hash_array}}) {
        my ($key_title, $value, $key) = @$pair;

        # value is a block. generate the HTML for it.
        if (blessed $value) {
            $value = $value->html(@_);
        }
        
        # Parse formatting in the value.
        else {
            $value = $page->parse_formatted_text($value);
        }
        
        # Parse formatting in the key.
        if (defined $key_title) {
            $key_title = $page->parse_formatted_text($key_title);
        }
        
        # append table row without key.
        
        if (!defined $key_title) {
        
        $string .= <<END

        <tr class="wiki-infobox-pair">
            <td class="wiki-infobox-anon" colspan="2">$value</td>
        </tr>
        
END
;
        }
        
        # append table row with key
        else {
        
        $string .= <<END

        <tr class="wiki-infobox-pair">
            <td class="wiki-infobox-key">$key_title</td>
            <td class="wiki-infobox-value">$value</td>
        </tr>
        
END
;
        }

    }
    
    $string .= "    </table>\n</div>\n";
    return $string;
}

__PACKAGE__
