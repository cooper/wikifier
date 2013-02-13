# Copyright (c) 2013, Mitchell Cooper
package Wikifier::BlockManager;

use warnings;
use strict;
use feature 'switch';

use Carp;

###################
### BLOCK TYPES ###
###################

# defines the types of blocks and the classes associated with them.
our %block_types = (
    main       => 'Wikifier::Block::Main',        # used only for main block.
    imagebox   => 'Wikifier::Block::Imagebox',    # displays an image with a caption.
    infobox    => 'Wikifier::Block::Infobox',     # displays a box of general information.
    section    => 'Wikifier::Block::Section',     # container for paragraphs, images, etc.
    paragraph  => 'Wikifier::Block::Paragraph',   # paragraph of text.
    image      => 'Wikifier::Block::Image',       # displays a standalone image.
    history    => 'Wikifier::Block::History',     # displays a table of dates and events.
    code       => 'Wikifier::Block::Code',        # displays a block of code.
    references => 'Wikifier::Block::References',  # displays a list of citations.
);

# create a new block of the given type.
sub create_block {
    my ($wikifier, %opts) = @_;
    my $class = $block_types{$opts{type}};
    $opts{wikifier} = $wikifier;
    
    # no such block type.
    if (!defined $class) {
        
        # if the type contains a hyphen, it's a subblock.
        if ($opts{type} =~ m/^(.*)\-(.+)$/) {
            # TODO.
        }

        # create a dummy block with no type.
        $opts{type} = 'dummy';
        return Wikifier::Block->new(%opts);
    }
    
    # load the class.
    my $file = $class.q(.pm);
    $file =~ s/::/\//g;
    if (!$INC{$file}) {
        require $file or croak "couldn't load block class '$opts{type}'";
    }
    
    # create a new block of the correct type.
    my $block = $class->new(%opts);
    
    return $block;
}

1
