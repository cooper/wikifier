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
use 5.010;

use Carp;
use Cwd qw(abs_path);

our %block_types;

sub create_block {
    my ($wikifier, %opts) = @_;
    
    # check for required options.
    # XXX: I don't think this is ever called directly.
    #      Is there even a change that options are missing?
    my @required = qw(parent type);
    foreach my $requirement (@required) {
        my ($pkg, $file, $line) = caller;
        carp "create_block(): missing option $requirement ($pkg line $line)"
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
    
    # is this an alias?
    if ($block_types{$type}{alias}) {
        $opts{type} = $block_types{$type}{alias};
        $type       = $opts{type};
    }
    
    # call init sub.
    my $block = Wikifier::Block->new(%opts);
    $block_types{$type}{init}->($block) if $block_types{$type}{init};
    
    return $block;
}

# load a block module.
sub load_block {
    my ($wikifier, $type) = @_;
    return 1 if $block_types{$type};
    my $file = q(lib/Wikifier/Block/).ucfirst(lc $type).q(.pm); # TODO: how to configure dir
    
    # does the file exist?
    if (!-f $file && !-l $file) {
        say "No such block file $file";
        return;
    }
    
    # find the absolute path.
    # if it's a symlink, we resolve it here so that
    # caches are not created separately for each link.
    $file = abs_path($file) or carp "cannot resolve $file", return;
    
    # do the file.
    my $package = do $file or carp "error loading $type block module: ".($@ || $! || 'idk');
    return unless $package;
    
    # fetch blocks.
    my %blocks;
    {
        no strict 'refs';
        %blocks = %{qq(${package}::block_types)};
    }

    # register blocks.
    foreach my $block_type (keys %blocks) {
        $block_types{$block_type} = $blocks{$block_type};
        
        # create aliases.
        if (my $aliases = delete $blocks{$block_type}{alias}) {
            $aliases = [$aliases] unless ref $aliases; # single alias.
            $block_types{$_} = { alias => $block_type } foreach @$aliases;
        }
        
        # if this depends on a base, load it.
        $wikifier->load_block($blocks{$block_type}{base}) if $blocks{$block_type}{base};
        
    }

    return 1;
}

1
