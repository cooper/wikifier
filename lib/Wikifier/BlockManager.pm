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

our %block_types;

sub create_block {
    my ($wikifier, %opts) = @_;
    my $type = $opts{type};
    my $dir  = _dir(\%opts);
    
    # if this block type doesn't exist, try loading its module.
    $wikifier->load_block($type, $dir) if !$block_types{$type};

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
    my $block = Wikifier::Block->new(%opts, wdir => $dir);
    $block_types{$type}{init}->($block) if $block_types{$type}{init};
    
    return $block;
}

# load a block module.
sub load_block {
    my ($wikifier, $type, $dir) = @_;
    return 1 if $block_types{$type};
    my $file = "$dir/lib/Wikifier/Block/".ucfirst(lc $type).q(.pm);
    
    # does the file exist?
    if (!-f $file && !-l $file) {
        Wikifier::l("Block \$type{} does not exist");
        return;
    }
    
    # do the file.
    my $package = do $file
        or Wikifier::l("Error loading $type\{} block: ".($@ || $! || 'but idk why'));
    return unless $package;
    
    # fetch blocks.
    my %blocks;
    {
        no strict 'refs';
        %blocks = %{ qq(${package}::block_types) };
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
        $wikifier->load_block($blocks{$block_type}{base}, $dir)
          if $blocks{$block_type}{base};
        
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
    return q(.); # fallback.
}

1
