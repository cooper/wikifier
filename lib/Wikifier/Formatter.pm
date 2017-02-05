# Copyright (c) 2016, Mitchell Cooper
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
use HTML::Entities ();
use Wikifier::Utilities qw(page_name_link trim);

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
#
sub parse_formatted_text {
    my ($wikifier, $page, $text, %opts) = @_;

    my @items;
    my $string       = '';
    my $last_char    = '';   # the last parsed character.
    my $in_format    = 0;    # inside a formatting element.
    my $format_type  = '';   # format name such as 'i' or '/b'
    my $escaped      = 0;    # this character was escaped.
    my $next_escaped = 0;    # the next character will be escaped.

    # parse character-by-character.
    CHAR: foreach my $char (split '', $text) {
        $next_escaped = 0;

        # escapes.
        if ($char eq '\\' && !$escaped) {
            $next_escaped = 1;
        }

        # [ marks the beginning of a formatting element.
        elsif ($char eq '[' && !$escaped) {

            # if we're in format already, it's a [[link]].
            if ($in_format && $last_char eq '[') {
                $format_type .= $char;

                # skip to next character.
                $last_char = $char;
                next CHAR;
            }

            # we are now inside the format type.
            $in_format   = 1;
            $format_type = '';

            # store the string we have so far.
            if (length $string) {
                push @items, [ $opts{no_entities}, $string ];
                $string = '';
            }
        }

        # ] marks the end of a formatting element.
        elsif ($char eq ']' && !$escaped) {

            # ignore it for now if it starts with [ and doesn't end with ].
            # this means it's a [[link]] which hasn't yet handled the second ].
            my $first = substr $format_type, 0, 1;
            my $last  = substr $format_type, -1, 1;
            if ($in_format && $first eq '[' && $last ne ']') {
                $format_type .= $char;
                $in_format    = 0;
            }

            # otherwise, the format type is ended and must now be parsed.
            else {
                push @items, [
                    1,
                    $wikifier->parse_format_type($page, $format_type, @_)
                ];
                $in_format = 0;
            }
        }

        # any other character.
        else {

            # if we're in the format type, append to it.
            if ($in_format) { $format_type .= $char }

            # it's any regular character, either within or outside of a format.
            else { $string .= $char }
        }

        # set last character and escape for next character.
        $last_char = $char;
        $escaped   = $next_escaped;
    }

    # final string item.
    push @items, [ $opts{no_entities}, $string ] if length $string;

    # might be a blessed object
    return $items[0][1] if $#items == 0 && blessed $items[0][1];

    # join them together, adding HTML entities when necessary.
    return join '', map {
        my ($fmtd, $value) = @$_;
        $fmtd ? $value : HTML::Entities::encode($value)
    } @items;
}

my %static_formats = (
    'i'     => '<span style="font-style: italic;">',            # italic
    'b'     => '<span style="font-weight: bold;">',             # bold
    's'     => '<span style="text-decoration: line-through;">', # strike
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
    'br'    => '<br />',
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
        if (!defined $val) {
            $page->warning("Undefined variable \@$2")
                unless $opts{no_warnings};
            return '(null)';
        }

        # format text unless this is %var
        $val = $wikifier->parse_formatted_text($page, $val, no_variables => 1)
            if !ref $val && $1 ne '%';

        return $val;
    }

    # html entity.
    if ($type =~ /^&(.+)$/) {
        return "&$1;";
    }

    # a link in the form of [[link]], [!link!], or [$link$]
    # inner match should be most greedy.
    if ($type =~ /^([\!\[\$\~]+?)(.+)([\!\]\$\~]+?)$/) {
        my ($link_char, $inner, $link_type) = (trim($1), trim($2));
        my ($target, $text, $title) = ($inner, $inner, '');
        my $name_link = page_name_link($target);

        # format is <text>|<target>
        if ($inner =~ m/^(.+?)\|(.+)$/) {
            $text   = trim($1);
            $target = trim($2);
        }

        # internal wiki link [[ article ]]
        if ($link_char eq '[') {
            $link_type = 'internal';
            $title     = ucfirst $target;
            $target    = $page->wiki_opt('root.page')."/$name_link";
        }

        # category wiki link [~ category ~]
        elsif ($link_char eq '~') {
            $link_type = 'category';
            $title     = ucfirst $target;
            $target    = $page->wiki_opt('root.category')."/$name_link";
        }

        # external wiki link [! article !]
        elsif ($link_char eq '!') {
            my $external_link = page_name_link($target, 1);
            $link_type = 'external';
            $title     = $page->wiki_opt('external.name').': '.ucfirst($target);
            $target    = $page->wiki_opt('external.root')."/$external_link";
        }

        # other non-wiki link [$ url $]
        elsif ($link_char eq '$') {
            $link_type = 'other';
            $title     = 'External link';
        }

        $title = qq( title="$title") if $title;
        return qq{<a class="wiki-link-$link_type" href="$target"$title>$text</a>};
    }

    # fake references.
    if ($type eq 'ref') {
        $page->{reference_number} ||= 1;
        my $ref = $page->{reference_number}++;
        return qq{<sup style="font-size: 75%"><a href="#">[$ref]</a></sup>};
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
        return qq{<sup style="font-size: 75%"><a href="#wiki-ref-$type">[$type]</a></sup>};
    }

    # leave out anything else, I guess.
    return '';
}

1
