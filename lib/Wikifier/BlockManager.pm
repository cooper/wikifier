# Copyright (c) 2016, Mitchell Cooper
#
# Wikifier::BlockManager is in charge of managing block classes.
# When Wikifier::Parser divides wiki code into blocks, the block manager loads
# block classes as needed. These classes then register block types to this
# manager. Blocks are created from the manager using ->create_block().
#
package Wikifier::BlockManager;

use warnings;
use strict;
use 5.010;

use Wikifier::Utilities qw(L);

our %block_types = (
    if      => { title => 1 },
    else    => { }
);

# creates a new block.
# see Block.pm for accepted options
sub create_block {
    my ($wikifier, %opts) = @_;
    my $c_maybe = $opts{current};
    my $type = $opts{type};
    my $dir  = _dir(\%opts);

    # this will be weakened in new().
    $opts{wikifier} = $wikifier;

    # if this block type doesn't exist, try loading its module.
    my $type_ref = $block_types{$type};
    $wikifier->load_block($type, $dir) if !$type_ref;
    $type_ref = $block_types{$type};

    # is this an alias?
    if ($type_ref && length $type_ref->{alias}) {
        $opts{type} = $type = $type_ref->{alias};
        $type_ref = $block_types{$type};
    }

    # if it still doesn't exist, make a dummy.
    if (!$type_ref) {
        $c_maybe->warning("Unknown block type $type\{}") if $c_maybe;
        return Wikifier::Block->new(
            type => 'dummy',
            %opts
        );
    }

    # Safe point - the block type is real and is loaded.

    # call init sub.
    my $block = ($type_ref->{package} || 'Wikifier::Block')->new(
        type_ref => $type_ref,  # reference to the block type
        %opts,                  # options passed to ->create_block
        wdir => $dir            # wikifier directory
    );
    $type_ref->{init}($block) if $type_ref->{init};

    return $block;
}

# load a block module.
sub load_block {
    my ($wikifier, $type, $dir) = @_;
    return 1 if $block_types{$type};
    return 1 unless length $type;
    my $file = "$dir/lib/Wikifier/Block/".ucfirst(lc $type).'.pm';

    # does the file exist?
    if (!-f $file && !-l $file) {
        L "Block ${type}{} does not exist";
        return;
    }

    # do the file.
    my $main_package = do $file;
    if (!$main_package) {
        L "Error loading ${type}{} block: ".($@ || $!);
        return;
    }

    # fetch blocks.
    my %blocks;
    {
        no strict 'refs';
        %blocks = %{ "${main_package}::block_types" };
    }

    # register blocks.
    foreach my $block_type (keys %blocks) {
        my $type_ref = $blocks{$block_type};

        # find the package. this may or may not exist already
        my $package = 'Wikifier::Block::'.ucfirst($block_type);

        # store the type ref
        $type_ref->{package} = $package;
        $block_types{$block_type} = $type_ref;

        # make the package inherit from its base
        my $base = $type_ref->{base} ?
            'Wikifier::Block::'.ucfirst($type_ref->{base}) : 'Wikifier::Block';
        {
            no strict 'refs';
            unshift @{ "${package}::ISA" }, $base;
        }

        # if this depends on a base, load it.
        $wikifier->load_block($type_ref->{base}, $dir)
            if $type_ref->{base};

        L "Loaded block ${block_type}{}";
    }

    return 1;
}

# find the wikifier directory.
sub _dir {
    my $b = shift;
    while (ref $b) {
        return $b->{wdir} if $b->{wdir};
        $b = $b->{parent};
    }
    return '.'; # fallback.
}

1
