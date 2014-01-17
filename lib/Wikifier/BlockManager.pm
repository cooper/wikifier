# Copyright (c) 2014, Mitchell Cooper
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

our %block_types;

###########################
### DEFAULT BLOCK TYPES ###
###########################

# defines the types of blocks and the classes associated with them.
#our %block_types = (
#    main       => 'Wikifier::Block::Main',        # used only for main block.
#    imagebox   => 'Wikifier::Block::Imagebox',    # displays an image with a caption.
#    infobox    => 'Wikifier::Block::Infobox',     # displays a box of general information.
#    section    => 'Wikifier::Block::Section',     # container for paragraphs, images, etc.
#    paragraph  => 'Wikifier::Block::Paragraph',   # paragraph of text.
#    image      => 'Wikifier::Block::Image',       # displays a standalone image.
#    history    => 'Wikifier::Block::History',     # displays a table of dates and events.
#    code       => 'Wikifier::Block::Code',        # displays a block of code.
#    references => 'Wikifier::Block::References',  # displays a list of citations.
#);

##############################
### BLOCK CLASS MANAGEMENT ###
##############################

# create a new block of the given type.
#sub create_block {
#    my ($wikifier, %opts) = @_;
#    
#    # check for required options.
#    my @required = qw(parent type);
#    foreach my $requirement (@required) {
#        my ($pkg, $file, $line) = caller;
#        croak "create_block(): missing option $requirement ($pkg line $line)"
#        unless exists $opts{$requirement};
#    }
#    
#    my $root_type = $opts{type};
#    my $sub_type;
#    
#    # if the type contains a hyphen, it's a subblock.
#    if ($opts{type} =~ m/^(.*)\-(.+)$/) {
#        $root_type = $1;
#        $sub_type  = $2;
#    }
#    
#    my $class = $block_types{$root_type};
#    
#    # no such block type.
#    if (!defined $class) {
#
#        # create a dummy block with no type.
#        $opts{type} = 'dummy';
#        return Wikifier::Block->new(%opts);
#    }
#    
#    # load the class.
#    my $file = $class.q(.pm);
#    $file =~ s/::/\//g;
#    if (!$INC{$file}) {
#        do $file or croak "couldn't load '$opts{type}' block class: ".
#        ($@ ? $@ : $! ? $! : 'unknown error');
#    }
#    
#    # create a new block of the correct type.
#    my $block = $class->new(wikifier => $wikifier, %opts);
#    
#    return $block;
#    
#}

sub create_block {
    my ($wikifier, %opts) = @_;
    print "create block @_\n";
    # check for required options.
    # XXX: I don't think this is ever called directly.
    #      Is there even a change that options are missing?
    my @required = qw(parent type);
    foreach my $requirement (@required) {
        my ($pkg, $file, $line) = caller;
        croak "create_block(): missing option $requirement ($pkg line $line)"
        unless exists $opts{$requirement};
    }
    my $type = $opts{type};
    
    # if this block type doesn't exist, try loading its module.
    $wikifier->load_block($type) if !$block_types{$type};

    # if it still doesn't exist, make a dummy.
    return Wikifier::Block->new(
        type => 'dummy',
        %opts
    ) if !$block_types{$type};
    
    # it does exist at this point.
    my %type_opts = %{ $block_types{$type} };
    
    # is this an alias?
    $opts{type} = $block_types{$type}{alias} if $block_types{$type}{alias};
    
    print "wow\n";
    return Wikifier::Block->new(%opts);
}

# load a block module.
sub load_block {
    print "load block: @_\n";
    my ($wikifier, $type) = @_;
    return 1 if $block_types{$type};
    
    # is there a file?
    my $file = q(lib/Wikifier/Block/).lc($type).q(.pm);
    croak "no such type $type", return if !-f $file && !-l $file;
    
    # do the file.
    my $package = do $file or croak "error loading $type block module: ".($@ || $! || 'idk');
    
    # fetch blocks.
    my %blocks;
    {
        no strict 'refs';
        %blocks = %{qq(${package}::block_types)};
    }

    # register blocks.
    foreach my $block_type (keys %blocks) {
        $block_types{$block_type} = $blocks{$block_type};
        # TODO: aliases.
    }
    print "made it\n";

    return 1;
}

1
