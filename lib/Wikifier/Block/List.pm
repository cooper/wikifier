#
# Copyright (c) 2014, Mitchell Cooper
#
package Wikifier::Block::List;

use warnings;
use strict;

use Scalar::Util 'blessed';

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
    my $block = shift;
    my $value = '';
    
    # for each content item...
    ITEM: foreach my $item (@{ $block->{content} }) {

        # if blessed, it's a block value, such as an image.
        if (blessed($item)) {
            
            # set the value to the block item itself.
            $value = $item;
            
            next ITEM;
        }
        
        # for each character in this string...
        my $escaped; # true if the last was escape character
        my $i = 0;
        
        for (split //, $item) { $i++;
            my $char = $_;
            
            if ($char eq "\\") {
                continue if $escaped; # this backslash was escaped.
                $escaped = 1;
            }
            
            # a semicolon indicates the termination of a pair.
            elsif ($char eq ';') {
                
                # it was escaped.
                continue if $escaped;
                
                # remove spaces from value.
                $value =~ s/(^\s*)|(\s*$)//g unless blessed $value;
                
                # store the value.
                push @{ $block->{list_array} }, $value;
                
                # reset status.
                $value = '';
                
            }
            
            # any other characters.
            else {
                $value .= $char;
                $escaped = 0;
            }
            
        }   # end of character loop.
    }       # end of item loop.
    
    return 1;
}

sub list_html {
    my ($block, $page, $el) = @_;
    
    # start with a ul.
    $el->{type} = 'ul';
    
    # append each item.
    foreach my $item (@{ $block->{list_array} }) {
        $el->create_child(
            type       => 'li',
            class      => 'list-item',
            content    => $page->parse_formatted_text($item)
        );
    }
    
}

__PACKAGE__