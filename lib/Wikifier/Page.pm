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

my %wiki_defaults = (
    name            => 'Wiki',
    image_directory => './files',
    image_address   => '/files',  # relative to HTTP root.
    wiki_root       => '',        # AKA "/"
    variables       => {},
    size_images     => 'javascript',
    image_sizer     => undef
);

# create a new page.
sub new {
    my ($class, %opts) = @_;
    $opts{content} ||= [];
    return bless \%opts, $class;
}

# parses the file.
sub parse {
    my $page = shift;
    $page->{wikifier} = Wikifier->new(file => $page->{file});
    return $page->wikifier->parse($page);
}

# returns the generated page HTML.
sub html {
    my $page = shift;
    return $page->{wikifier}{main_block}->result($page);
}

# set a variable.
sub set {
    my ($page, $var, $value) = @_;
    my ($hash, $name) = $page->_get_hash($var);
    $hash->{$name} = $value;
}

# fetch a variable.
sub get {
    my ($page, $var)  = @_;
    my ($hash, $name) = $page->_get_hash($var);
    return $hash->{$name};
}

# interna use only.
sub _get_hash {
    my ($page, $var) = @_;
    my $hash = ($page->{variables} ||= {});
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

sub wikifier { shift->{wikifier} }

1
