# Copyright (c) 2013, Mitchell Cooper
# 
# Wikifier::BlockManager is in charge of managing block classes. When Wikifier::Parser
# segregates wiki code into blocks, the BlockManager loads block classes as needed.
# These classes then register block types to the Wikifier using methods provided by this
# class. BlockManager also contains a list of default blocks and their associated classes.
#
package Wikifier::BlockManager;

use warnings;
use strict;
use feature 'switch';

use Carp;

###########################
### DEFAULT BLOCK TYPES ###
###########################

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

##############################
### BLOCK CLASS MANAGEMENT ###
##############################

# create a new block of the given type.
sub create_block {
    my ($wikifier, %opts) = @_;
    
    # check for required options.
    my @required = qw(parent type);
    foreach my $requirement (@required) {
        my ($pkg, $file, $line) = caller;
        croak "create_block(): missing option $requirement ($pkg line $line)"
        unless exists $opts{$requirement};
    }
    
    my $root_type = $opts{type};
    my $sub_type;
    
    # if the type contains a hyphen, it's a subblock.
    if ($opts{type} =~ m/^(.*)\-(.+)$/) {
        $root_type = $1;
        $sub_type  = $2;
    }
    
    my $class = $block_types{$root_type};
    
    # no such block type.
    if (!defined $class) {

        # create a dummy block with no type.
        $opts{type} = 'dummy';
        return Wikifier::Block->new(%opts);
    }
    
    # load the class.
    my $file = $class.q(.pm);
    $file =~ s/::/\//g;
    if (!$INC{$file}) {
        do $file or croak "couldn't load '$opts{type}' block class: ".
        ($@ ? $@ : $! ? $! : 'unknown error');
    }
    
    # create a new block of the correct type.
    my $block = $class->new(wikifier => $wikifier, %opts);
    
    return $block;
    
}
# register a block type.
sub register_block {
    my ($wikifier, %opts) = @_;
    return 1; # TODO.
    
}

1