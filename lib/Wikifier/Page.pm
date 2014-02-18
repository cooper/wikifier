#
# Copyright (c) 2014, Mitchell Cooper
#
# Wikifier::Page provides an objective interface to a wiki page or article. It implements
# the very user-friendly programming interface of the Wikifier.
#
package Wikifier::Page;

use warnings;
use strict;

# default options.
our %wiki_defaults = (
    'name'              => 'Wiki',
    'dir.wikifier'      => '.',
    'dir.image'         => 'images',
    'dir.page'          => 'pages',
    'dir.cache'         => 'cache',
    'root.image'        => '/images',   # relative to HTTP root.
    'root.page'         => '',          # AKA "/"
    'root.wiki'         => '',          # AKA "/"
    'image.size_method' => 'javascript',
    'external.name'     => 'Wikipedia',
    'external.root'     => 'http://en.wikipedia.org/wiki',
    'image.rounding'    => 'normal',
    'image.calc'        => \&_default_calculator,
    'var'               => {}
);

# create a new page.
sub new {
    my ($class, %opts) = @_;
    $opts{references} ||= [];
    $opts{content}    ||= [];
    $opts{variables}  ||= {};
    
    # no wikifier given, create a new one.
    $opts{wikifier} ||= Wikifier->new();
    my $wikifier = $opts{wikifier};
    
    # create the page.
    my $page = bless \%opts, $class;
    
    # create the page's main block.
    $page->{main_block} = $wikifier->{main_block} = $wikifier->create_block(
        dir    => $page->wiki_opt('dir.wikifier'),
        type   => 'main',
        parent => undef     # main block has no parent.
    );
    
    return $page;
}

# parses the file.
sub parse {
    my $page = shift;
    return $page->wikifier->parse($page, $page->{file});
}

# returns the generated page HTML.
sub html {
    my $page = shift;
    $page->{wikifier}{main_block}->html($page);
    return $page->{wikifier}{main_block}{element}->generate;
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

# internal use only.
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
sub wiki_opt {
    my ($page, $var) = @_;
    return $page->{wiki}->opt($var) if $page->{wiki};
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
    # note: these are provided by GD in WiWiki.
    if (!$w || !$h) {
        require Image::Size;
        my $dir = $img{page}->wiki_opt('dir.image');
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
    my $round = $page->wiki_opt('image.rounding');
    return int($size + 0.5 ) if $round eq 'normal';
    return int($size + 0.99) if $round eq 'up';
    return int($size       ) if $round eq 'down';
    return $size; # fallback.
}

sub wikifier { shift->{wikifier} }

1
