#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# Wikifier::Page provides an objective interface to a wiki page or article. It implements
# the very user-friendly programming interface of the Wikifier.
#
package Wikifier::Page;

use warnings;
use strict;
use feature qw(switch);

# wiki info.
#   name:               simple name of the wiki, such as "NoTrollPlzNet Library."
#   image_directory:    local directory containing wiki media files and images.
#   image_address:      HTTP address of file directory, such as http://example.com/files .
#   wiki_root:          HTTP address of wiki root (typically relative to /)
#   variables:          a hash reference of global wiki variables.
#   size_images:        either 'javascript' or 'server' (see below)
#   image_sizer:        a code reference returning URL to resized image (see below)
#   external_name:      name of external wiki (defaults to Wikipedia)
#   external_root:      HTTP address of external wiki root (defaults to en.wikipedia.org)
#   rounding:           'normal', 'up', or 'down' for how dimensions should be rounded.
#   image_dimension_calculator: code returning dimensions of a resized image

# Image sizing with a server:
#
# The wikifier can make use of server-side image sizers using the image_sizer wiki option.
# This allows you to provide a code reference which takes several options as arguments
# and returns the full or relative URL to an image scaled in accordance of the options.
#
# This also requires that the 'image_directory' setting is correctly set to a readable
# local filesystem directory containing the images. This is used to determine the image's
# actual dimensions beforehand, eliminating the need for JavaScript imagebox sizing.
#
# To use server sizing, set 'size_images' to 'server' and 'image_sizer' to your handler.
#
# The options (passed as pure hash) provided to image_sizer code include:
#   file:   the name of the image file.
#   width:  the desired  width, in pixels, of the image or 'auto' if not provided.
#   height: the desired height, in pixels, of the image or 'auto' if not provided.
#
# The returned URL will be used directly as the value of the 'src' attribute of the image.
#
# An example handler may look like this:
#
# my $handler = sub {
#   my %opts = shift;
#   return "http://mywebsite.com/image/$opts{file}?height=$opts{height}&width=$opts{width}";
# }
#
# A possible return value might be:
# http://mywebsite.com/image/Rosetta_Stone.png?height=auto&width=200
#

# Image sizing without a server:
# 
# Although not recommended, the wikifier can directly insert entire images and scale them
# using HTML and JavaScript. This causes pages to take longer to load (due to larger
# image file sizes) and also voids XHTML 1.0 Strict validity.
# 
# If server sizing is not an option, set wiki option 'size_images' to 'javascript' and
# do not provide an 'image_sizer' option.
#

our %wiki_defaults = (
    name            => 'Wiki',
    image_directory => './files',
    image_address   => '/files',  # relative to HTTP root.
    wiki_root       => '',        # AKA "/"
    variables       => {},
    size_images     => 'javascript',
    image_sizer     => undef,
    external_root   => 'http://en.wikipedia.org/wiki',
    rounding        => 'normal',
    image_dimension_calculator => \&_default_calculator
);

# create a new page.
sub new {
    my ($class, %opts) = @_;
    $opts{references} ||= [];
    $opts{content}    ||= [];
    $opts{variables}  ||= {};
    
    # no wikifier given, create a new one.
    $page->{wikifier} ||= Wikifier->new();
    
    # create the page's main block.
    $page->{main_block} = $wikifier->create_block(
        type   => 'main',
        parent => undef     # main block has no parent.
    );
    
    # initial parser hashes.
    $wikifier->{parse_current} = { block => $main_block };
    $wikifier->{parse_last}    = { block => undef       };
    
    return bless \%opts, $class;
}

# parses the file.
sub parse {
    my $page = shift;
    return $page->wikifier->parse($page, $page->{file});
}

# returns the generated page HTML.
sub html {
    my $page = shift;
    return $page->{wikifier}{main_block}->result($page);
}

# set a variable.
sub set {
    my ($page, $var, $value) = @_;
    my ($hash, $name) = _get_hash($page->{variables}, $var);
    $hash->{$name} = $value;
}

# fetch a variable.
sub get {
    my ($page, $var)  = @_;
    
    # try page variables.
    my ($hash, $name) = _get_hash($page->{variables}, $var);
    return $hash->{$name} if defined $hash->{$name};
    
    # try global variables.
    ($hash, $name) = _get_hash($page->{wiki}{variables}, $var);
    return $hash->{$name};
    
}

# interna use only.
sub _get_hash {
    my ($hash, $var) = @_;
    my $i    = 0;
    my @parts = split /\./, $var;
    foreach my $part (@parts) {
        last if $i == $#parts;
        $hash->{$part} ||= {};
        $hash = $hash->{$part};
        $i++;
    }
    return ($hash, $parts[-1]);
}

# returns HTML for formatting.
sub parse_formatted_text {
    my ($page, $text) = @_;
    return $page->wikifier->parse_formatted_text($page, $text);
}

# returns a wiki option or the default.
sub wiki_info {
    my ($page, $var) = @_;
    return $page->{wiki}{$var} if defined $page->{wiki}{$var};
    return $wiki_defaults{$var};
}

# default image dimension calculator. requires Image::Size.
sub _default_calculator {
    my %img = @_;
    my ($width, $height) = ($img{width}, $img{height});
    
    # decide which dimension(s) were given.
    my $given_width  = defined $width  && $width  ne 'auto' ? 1 : 0;
    my $given_height = defined $height && $height ne 'auto' ? 1 : 0;
    
    # maybe these were found for us already.
    my ($w, $h) = ($img{big_width}, $img{big_height});
    
    # gotta do it the hard way.
    # use Image::Size to determine the dimensions.
    if (!$w || !$h) {
        require Image::Size;
        my $dir = $img{page}->wiki_info('image_directory');
        ($w, $h) = Image::Size::imgsize("$dir/$img{file}");
    }

    # now we must find the scaling factor.
    my $scale_factor;
    
    # width was given; calculate height.
    if ($given_width) {
        $scale_factor = $w / $width;
        $w = $img{width};
        $h = $img{page}->image_round($h / $scale_factor);
    }
    
    # height was given; calculate width.
    if ($given_height) {
        $scale_factor = $h / $height;
        $w = $img{page}->image_round($w / $scale_factor);
        $h = $img{height};
    }

    return ($w, $h);
}

# round dimension according to setting.
sub image_round {
    my ($page, $size) = @_;
    my $round = $page->wiki_info('rounding');
    return int($size + 0.5 ) if $round eq 'normal';
    return int($size + 0.99) if $round eq 'up';
    return int($size       ) if $round eq 'down';
    return $size; # fallback.
}

sub wikifier { shift->{wikifier} }

1
