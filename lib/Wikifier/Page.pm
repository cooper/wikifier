#
# Copyright (c) 2014, Mitchell Cooper
#
# Wikifier::Page provides an objective interface to a wiki page or article. It implements
# the very user-friendly programming interface of the Wikifier.
#
package Wikifier::Page;

use warnings;
use strict;
use Scalar::Util 'blessed';

# default options.
our %wiki_defaults = (
    'name'              => 'Wiki',
    'dir.wikifier'      => '.',
    'dir.image'         => 'images',
    'dir.page'          => 'pages',
    'dir.cache'         => 'cache',
    'dir.model'         => 'models',
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
        wdir   => $page->wiki_opt('dir.wikifier'),
        type   => 'main',
        parent => undef     # main block has no parent.
    );
    
    return $page;
}

# parses the file.
sub parse {
    my $page = shift;

    Wikifier::lindent("Parse     $$page{name}");
    my $res = $page->wikifier->parse($page, $page->{file});
    Wikifier::back();
    
    return $res;
}

# returns the generated page HTML.
sub html {
    my $page = shift;
    Wikifier::lindent("HTML      $$page{name}");
    $page->{wikifier}{main_block}->html($page);
    Wikifier::back();
    
    Wikifier::lindent("Generate  $$page{name}");
    my $res = $page->{wikifier}{main_block}{element}->generate;
    Wikifier::back();
    
    return $res;
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
    my ($page, $text, $no_html_entities) = @_;
    return $page->wikifier->parse_formatted_text($page, $text, $no_html_entities);
}

# returns a wiki option or the default.
sub wiki_opt {
    my ($page, $var) = @_;
    return $page->{wiki}->opt($var) if blessed $page->{wiki};
    return $wiki_defaults{$var};
}

# default image dimension calculator. requires Image::Size.
sub _default_calculator {
    my %img = @_;
    my ($width, $height) = ($img{width}, $img{height});
    
    # maybe these were found for us already.
    my ($big_w, $big_h) = ($img{big_width}, $img{big_height});
    
    # gotta do it the hard way.
    # use Image::Size to determine the dimensions.
    # note: these are provided by GD in WiWiki.
    if (!$big_w || !$big_h) {
        require Image::Size;
        my $dir = $img{page}->wiki_opt('dir.image');
        ($big_w, $big_h) = Image::Size::imgsize("$dir/$img{file}");
    }
    
    # neither dimensions were given. use the full size.
    if (!$width && !$height) {
        return ($big_w, $big_h, 1);
    }
    
    # now we must find the scaling factor.
    my $scale_factor;
    my ($final_w, $final_h);
    
    # width was given; calculate height.
    if ($width) {
        $scale_factor = $big_w / $width;
        $final_w = $img{width};
        $final_h = $img{page}->image_round($big_h / $scale_factor);
    }
    
    # height was given; calculate width.
    elsif ($height) {
        $scale_factor = $big_h / $height;
        $final_w = $img{page}->image_round($big_w / $scale_factor);
        $final_h = $img{height};
    }

    return ($final_w, $final_h);
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
