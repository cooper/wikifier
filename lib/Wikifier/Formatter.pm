# Copyright (c) 2017, Mitchell Cooper
#
# Wikifier::Formatter is in charge of text formatting. Block types use the
# functions provided by the Formatter to convert formatted wiki source such as
# [b]hello[/b] to formatted HTML.
#
package Wikifier::Formatter;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);
use HTML::Entities qw(encode_entities);
use Wikifier::Utilities qw(page_name_link page_name cat_name trim resolve_dots);
use URI::Escape qw(uri_escape);

our %colors = (
    AliceBlue               => '#F0F8FF',
    AntiqueWhite            => '#FAEBD7',
    Aqua                    => '#00FFFF',
    Aquamarine              => '#7FFFD4',
    Azure                   => '#F0FFFF',
    Beige                   => '#F5F5DC',
    Bisque                  => '#FFE4C4',
    Black                   => '#000000',
    BlanchedAlmond          => '#FFEBCD',
    Blue                    => '#0000FF',
    BlueViolet              => '#8A2BE2',
    Brown                   => '#A52A2A',
    BurlyWood               => '#DEB887',
    CadetBlue               => '#5F9EA0',
    Chartreuse              => '#7FFF00',
    Chocolate               => '#D2691E',
    Coral                   => '#FF7F50',
    CornflowerBlue          => '#6495ED',
    Cornsilk                => '#FFF8DC',
    Crimson                 => '#DC143C',
    Cyan                    => '#00FFFF',
    DarkBlue                => '#00008B',
    DarkCyan                => '#008B8B',
    DarkGoldenRod           => '#B8860B',
    DarkGray                => '#A9A9A9',
    DarkGreen               => '#006400',
    DarkKhaki               => '#BDB76B',
    DarkMagenta             => '#8B008B',
    DarkOliveGreen          => '#556B2F',
    DarkOrange              => '#FF8C00',
    DarkOrchid              => '#9932CC',
    DarkRed                 => '#8B0000',
    DarkSalmon              => '#E9967A',
    DarkSeaGreen            => '#8FBC8F',
    DarkSlateBlue           => '#483D8B',
    DarkSlateGray           => '#2F4F4F',
    DarkTurquoise           => '#00CED1',
    DarkViolet              => '#9400D3',
    DeepPink                => '#FF1493',
    DeepSkyBlue             => '#00BFFF',
    DimGray                 => '#696969',
    DodgerBlue              => '#1E90FF',
    FireBrick               => '#B22222',
    FloralWhite             => '#FFFAF0',
    ForestGreen             => '#228B22',
    Fuchsia                 => '#FF00FF',
    Gainsboro               => '#DCDCDC',
    GhostWhite              => '#F8F8FF',
    Gold                    => '#FFD700',
    GoldenRod               => '#DAA520',
    Gray                    => '#808080',
    Green                   => '#008000',
    GreenYellow             => '#ADFF2F',
    HoneyDew                => '#F0FFF0',
    HotPink                 => '#FF69B4',
    IndianRed               => '#CD5C5C',
    Indigo                  => '#4B0082',
    Ivory                   => '#FFFFF0',
    Khaki                   => '#F0E68C',
    Lavender                => '#E6E6FA',
    LavenderBlush           => '#FFF0F5',
    LawnGreen               => '#7CFC00',
    LemonChiffon            => '#FFFACD',
    LightBlue               => '#ADD8E6',
    LightCoral              => '#F08080',
    LightCyan               => '#E0FFFF',
    LightGoldenRodYellow    => '#FAFAD2',
    LightGray               => '#D3D3D3',
    LightGreen              => '#90EE90',
    LightPink               => '#FFB6C1',
    LightSalmon             => '#FFA07A',
    LightSeaGreen           => '#20B2AA',
    LightSkyBlue            => '#87CEFA',
    LightSlateGray          => '#778899',
    LightSteelBlue          => '#B0C4DE',
    LightYellow             => '#FFFFE0',
    Lime                    => '#00FF00',
    LimeGreen               => '#32CD32',
    Linen                   => '#FAF0E6',
    Magenta                 => '#FF00FF',
    Maroon                  => '#800000',
    MediumAquaMarine        => '#66CDAA',
    MediumBlue              => '#0000CD',
    MediumOrchid            => '#BA55D3',
    MediumPurple            => '#9370DB',
    MediumSeaGreen          => '#3CB371',
    MediumSlateBlue         => '#7B68EE',
    MediumSpringGreen       => '#00FA9A',
    MediumTurquoise         => '#48D1CC',
    MediumVioletRed         => '#C71585',
    MidnightBlue            => '#191970',
    MintCream               => '#F5FFFA',
    MistyRose               => '#FFE4E1',
    Moccasin                => '#FFE4B5',
    NavajoWhite             => '#FFDEAD',
    Navy                    => '#000080',
    OldLace                 => '#FDF5E6',
    Olive                   => '#808000',
    OliveDrab               => '#6B8E23',
    Orange                  => '#FFA500',
    OrangeRed               => '#FF4500',
    Orchid                  => '#DA70D6',
    PaleGoldenRod           => '#EEE8AA',
    PaleGreen               => '#98FB98',
    PaleTurquoise           => '#AFEEEE',
    PaleVioletRed           => '#DB7093',
    PapayaWhip              => '#FFEFD5',
    PeachPuff               => '#FFDAB9',
    Peru                    => '#CD853F',
    Pink                    => '#FFC0CB',
    Plum                    => '#DDA0DD',
    PowderBlue              => '#B0E0E6',
    Purple                  => '#800080',
    Red                     => '#FF0000',
    RosyBrown               => '#BC8F8F',
    RoyalBlue               => '#4169E1',
    SaddleBrown             => '#8B4513',
    Salmon                  => '#FA8072',
    SandyBrown              => '#F4A460',
    SeaGreen                => '#2E8B57',
    SeaShell                => '#FFF5EE',
    Sienna                  => '#A0522D',
    Silver                  => '#C0C0C0',
    SkyBlue                 => '#87CEEB',
    SlateBlue               => '#6A5ACD',
    SlateGray               => '#708090',
    Snow                    => '#FFFAFA',
    SpringGreen             => '#00FF7F',
    SteelBlue               => '#4682B4',
    Tan                     => '#D2B48C',
    Teal                    => '#008080',
    Thistle                 => '#D8BFD8',
    Tomato                  => '#FF6347',
    Turquoise               => '#40E0D0',
    Violet                  => '#EE82EE',
    Wheat                   => '#F5DEB3',
    White                   => '#FFFFFF',
    WhiteSmoke              => '#F5F5F5',
    Yellow                  => '#FFFF00',
    YellowGreen             => '#9ACD32'
);

%colors = map { lc $_ => $colors{$_} } keys %colors;

######################
### FORMAT PARSING ###
######################
#
# %opts
#
#   no_entities         disables HTML entity conversion
#   no_variables        used internally to prevent recursion
#   no_warnings         silence warnings for undefined variables
#   pos                 position used for warnings, defaults to $page->pos
#   startpos            set internally to the position of the '[' character
#
sub parse_formatted_text {
    my ($wikifier, $page, $text, %opts) = @_;
    return '' if !length $text;
    
    # find and copy the position
    my $pos = $opts{pos} || $page->pos;
    $pos = $opts{pos} = { %$pos };

    my @items;
    my $string       = '';
    my $format_type  = '';   # format name such as 'i' or '/b'
    my $in_format    = 0;    # inside a formatting element.
    my $escaped      = 0;    # this character was escaped.

    # parse character-by-character.
    my @chars = split '', $text;
    CHAR: foreach my $i (0..$#chars) {
        my $char = $chars[$i];
        my $last_char = $i == 0 ? '' : $chars[$i - 1];

        # update position
        if ($char eq "\n") {
            $pos->{line}++;
            $pos->{col} = 0;
        }
        else {
            $pos->{col}++;
        }

        # [ marks the beginning of a formatting element.
        if ($char eq '[' && !$escaped) {
            if (!$in_format++) {
                $opts{startpos} = { %$pos };
                $format_type    = '';

                # store the string we have so far.
                if (length $string) {
                    push @items, [ $opts{no_entities}, $string ];
                    $string = '';
                }

                next;
            }
        }

        # ] marks the end of a formatting element.
        elsif ($char eq ']' && !$escaped && $in_format) {
            if (!--$in_format) {
                push @items, [
                    1,
                    $wikifier->parse_format_type($page, $format_type, %opts)
                ];
                delete $opts{startpos};
                next;
            }
        }
        
        # an unescaped backslash should not appear in the result.
        $escaped = $char eq '\\' && !$escaped;
        next if $escaped && !$in_format;

        # if we're in the format type, append to it.
        if ($in_format) { $format_type .= $char }

        # it's any regular character, either within or outside of a format.
        else { $string .= $char }
    }

    # final string item.
    push @items, [ $opts{no_entities}, $string ]
        if length $string;

    # might be a blessed object
    return $items[0][1] if $#items == 0 && blessed $items[0][1];

    # join them together, adding HTML entities when necessary.
    return join '', map {
        my ($fmtd, $value) = @$_;
        $fmtd ? $value : encode_entities($value)
    } @items;
}

my %static_formats = (
    'i'     => '<span style="font-style: italic;">',            # italic
    'b'     => '<span style="font-weight: bold;">',             # bold
    's'     => '<span style="text-decoration: line-through;">', # strike
    'c'     => '<code>',                                        # inline code
    '/c'    => '</code>',
    '/s'    => '</span>',
    '/b'    => '</span>',
    '/i'    => '</span>',
    'q'     => '<span style="font-style: italic;">"',           # inline quote
    '/q'    => '"</span>',
    '^'     => '<sup>',                                         # superscript
    '/^'    => '</sup>',
    'v'     => '<sub>',                                         # subscript
    '/v'    => '</sub>',
    '/'     => '</span>',
    'nl'    => '<br />',                                        # line break
    'br'    => '<br />',                                        # (deprecated)
    '--'    => '&ndash;',                                       # en dash
    '---'   => '&mdash;'                                        # em dash
);

# parses an individual format type, aka the content in [brackets].
# for example, 'i' for italic. returns the string generated from it.
sub parse_format_type {
    my ($wikifier, $page, $type, %opts) = @_;

    # static format from above
    if (my $fmt = $static_formats{$type}) {
        return $fmt;
    }

    # variable.
    if ($type =~ /^([@%])([\w\.]+)$/ && !$opts{no_variables}) {
        my $val = $page->get($2);

        # undefined variable
        if (!defined $val && $2 !~ m/^m\./) {
            $page->warning($opts{startpos}, "Undefined variable $1$2")
                unless $opts{no_warnings};
            return '(null)';
        }

        # format text if this is %var
        $val = $wikifier->parse_formatted_text($page, $val, no_variables => 1)
            if !ref $val && $1 eq '%';

        return $val;
    }

    # html entity.
    if ($type =~ /^&(.+)$/) {
        return "&$1;";
    }

    # deprecated: a link in the form of [~link~], [!link!], or [$link$]
    # convert to newer link format
    if ($type =~ /^([\!\$\~]+?)(.+)([\!\$\~]+?)$/) {
        my ($link_char, $inner) = ($1, $2);
        my ($target, $text) = ($inner, $inner);

        # format is <text>|<target>
        if ($inner =~ m/^(.+)\|(.+?)$/) {
            $text   = $1;
            $target = $2;
        }

        # category wiki link [~ category ~]
        if ($link_char eq '~') {
            $type = "[ $text | ~ $target ]";
        }

        # external wiki link [! article !]
        # technically this used to observe @external.name and @external.root,
        # but in practice this was always set to wikipedia, so use 'wp'
        elsif ($link_char eq '!') {
            $type = "[ $text | wp: $target ]";
        }

        # other non-wiki link [$ url $]
        elsif ($link_char eq '$') {
            $type = "[ $text | $target ]";
        }
    }

    # [[link]]
    if ($type =~ /^\[(.+)\]$/) {
        my ($ok, $target, $display, $tooltip, $link_type, $display_same) =
            $wikifier->parse_link($page, $1, %opts);

        # text formatting is permitted before the pipe.
        # do nothing when the link did not have a pipe ($display_same)
        $display = $wikifier->parse_formatted_text($page, $display, %opts)
            unless $display_same;

        return sprintf '<a class="wiki-link-%s%s" href="%s"%s>%s</a>',
            $link_type,
            $ok ? '' : ' invalid',
            $target,
            length $tooltip ? qq{ title="$tooltip"} : '',
            $display;
    }

    # fake references.
    if ($type eq 'ref') {
        $page->{reference_number} ||= 1;
        my $ref = $page->{reference_number}++;
        return qq{<sup style="font-size: 75%"><a href="#wiki-ref-$ref" class="wiki-ref-anchor">[$ref]</a></sup>};
    }

    # color name.
    if (my $color = $colors{ lc $type }) {
        return qq{<span style="color: $color;">};
    }

    # color hex code.
    if ($type =~ m/^#[\da-f]+$/i) {
        return qq{<span style="color: $type;">};
    }

    # real references.
    if ($type =~ m/^\d+$/) {
        return qq{<sup style="font-size: 75%"><a href="#wiki-ref-$type" class="wiki-ref-anchor">[$type]</a></sup>};
    }

    # leave out anything else, I guess.
    return '';
}

sub parse_link {
    my ($wikifier, $page, $input, %opts) = @_;
    my ($display, $target) = map trim($_), split(m/\|/, $input, 2);
    my ($tooltip, $link_type, $normalize) = '';
    my @normalize_args = %opts;

    # no pipe
    my $display_same;
    if (!length $target) {
        $target = $display;
        $display_same++;
    }

    # http://google.com or $/something (see issue #68)
    my $link_re = qr{^((\w+)://|\$)};
    my $mlto_re = qr{^mailto:};
    my $mail_re = qr{^[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,63}$}i;
    if ($target =~ $link_re) {
        $link_type  = 'other';
        $normalize  = \&_other_link;
        $display    =~ s/$link_re// if $display_same;
    }
    
    # mailto:someone@example.com (see issue #69)
    elsif ($target =~ $mlto_re) {
        $link_type = 'contact';
        $normalize = \&_email_link;
        $display   =~ s/$mlto_re// if $display_same;
    }
    
    # someone@example.com
    elsif ($target =~ $mail_re) {
        $link_type = 'contact';
        $normalize = \&_email_link;
    }
    
    # wp: some page
    elsif ($target =~ s/^(\w+)://) {
        unshift @normalize_args, $1;
        $target     = trim($target);
        $link_type  = 'external';
        $normalize  = \&_external_link;
        $display    =~ s/^(\w+):// if $display_same;
    }

    # ~ some category
    elsif ($target =~ s/^\~//) {
        $target     = trim($target);
        $link_type  = 'category';
        $normalize  = \&_category_link;
        $display    =~ s/^\~// if $display_same;
    }

    # normal page link
    else {
        $link_type  = 'internal';
        $normalize  = \&_page_link;
    }

    # normalize
    my $display_dummy = '';
    ($target, $tooltip, $display) = map trim($_),
        $target, $tooltip, $display;
    my $ok = $normalize->(
        \$target,
        \$tooltip,
        $display_same ? \$display : \$display_dummy,
        $page,
        @normalize_args
    );

    return ($ok, $target, $display, $tooltip, $link_type, $display_same);
}

my %normalizers = (
    wikifier  => sub {
        my $target = shift;
        return page_name_link($target);
    },
    mediawiki => sub {
        my $target = shift;
        return undef if !defined $target;
        $target =~ s/ /_/g;
        return uri_escape(ucfirst $target);
    },
    none => sub {
        my $target = shift;
        return uri_escape($target);
    }
);

sub _page_link      { __page_link('page',     @_) }
sub _category_link  { __page_link('category', @_) }

# a page link on the same wiki
sub __page_link {
    my ($typ, $target_ref, $tooltip_ref, $display_ref, $page, %opts) = @_;

    # split the target up into page and section
    my ($target, $section) = map trim($_),
        split(/#/, $$target_ref, 2);
        
    # create tooltip
    my $page_name_hr = $target;
    $page_name_hr =~ s/(.*)\///g;
    $$tooltip_ref = join ' # ', map ucfirst,
        grep length, $page_name_hr, $section;
    $$display_ref = length $section ? $section : $target;

    # if it starts with /, it is relative to the root
    my $start_root = $target =~ s{^/}{};

    # apply the normalizer to both page and section
    ($target, $section) = map page_name_link($_), $target, $section;

    $$target_ref  = '';
    my $errors;
    if (length $target) {
        
        # category target
        my ($safe_name, $full_name, $path, $page_target);
        if ($typ eq 'category') {
            $safe_name = $full_name = cat_name($target);
            my $cat_dir = $page->opt('dir.cache').'/category';
            $path = join '/', $cat_dir, $safe_name;
            $page_target = join '/',
                $page->opt('root.category'), $target;
        }
        
        # page target, respecting page prefix
        else {
            my $prefix = $start_root ? '' : $page->prefix;
            $safe_name = page_name($target);
            $full_name = resolve_dots(join '/', grep length,
                $prefix, $safe_name);
            $path = join '/',
                $page->opt('dir.page'), $full_name;
            $page_target = resolve_dots(join '/', grep length,
                $page->opt('root.page'), $page->prefix, $target);
        }
            
        # make sure the page/category exists
        if (!-e $path) {
            $page->warning(
                $opts{startpos},
                "Page target '$page_name_hr' does not exist"
            ) unless $opts{no_warnings};
            $errors++;
        }
        
        # add the target
        push @{ $page->{target_pages}{$full_name} ||= [] },
            $opts{startpos}{line} if $typ eq 'page';
        $$target_ref .= $page_target;
    }

    # add the section
    $$target_ref .= "#$section" if length $section;

    return !$errors;
}

# a page link an external wiki
sub _external_link {
    my ($target_ref, $tooltip_ref, $display_ref, $page, $wiki_id, %opts) = @_;
    my ($wiki_name, $wiki_root, $wiki_normalizer) =
        map $page->opt("external.$wiki_id.$_"), qw(name root type);

    # no such external wiki is configured
    my $errors;
    if (!length $wiki_name) {
        $page->warning($opts{startpos}, "No such external wiki '$wiki_id'")
            unless $opts{no_warnings};
        $wiki_name = $wiki_id;
        $errors++;
    }

    # find the normalizer
    $wiki_normalizer = $normalizers{ $wiki_normalizer || 'wikifier' }
        if !ref $wiki_normalizer;
    if (!$wiki_normalizer) {
        $page->warning($opts{startpos}, "No such normalizer for '$wiki_id'")
            unless $opts{no_warnings};
        $wiki_normalizer = $normalizers{wikifier};
        $errors++;
    }

    # split the target up into page and section, then create tooltip
    my ($target, $section) = map trim($_),
        split(/#/, $$target_ref, 2);
    $$tooltip_ref   = join ' # ', map ucfirst, grep length, $target, $section;
    $$tooltip_ref   = "$wiki_name: $$tooltip_ref";
    $$display_ref   = length $section ? $section : $target;

    # apply the normalizer to both page and section, then create link
    ($target, $section) = map $wiki_normalizer->($_), $target, $section;
    $$target_ref   = "$wiki_root/$target";
    $$target_ref  .= '#'.$section if length $section;

    return !$errors;
}

# external site link
sub _other_link {
    my ($target_ref, $tooltip_ref, $display_ref, $page) = @_;
    $$target_ref  =~ s/^\$//;
    $$target_ref  = trim($$target_ref);
    $$tooltip_ref = 'External link';
    return 1;
}


# email link
sub _email_link {
    my ($target_ref, $tooltip_ref, $display_ref, $page) = @_;
    my $email = $$target_ref;
    if ($$target_ref =~ /^mailto:/) {
        $email = substr $email, 7;
    }
    else {
        $$target_ref = "mailto:$$target_ref";
    }
    $$tooltip_ref = "Email $email";
    return 1;
}

1
