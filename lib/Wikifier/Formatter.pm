# Copyright (c) 2014, Mitchell Cooper
#
# Wikifier::Formatter is in charge of text formatting. Block types use the functions
# provided by the Formatter to convert formatted wiki source such as '[b]hello[/b]' to
# formatted XHTML.
#
package Wikifier::Formatter;

use warnings;
use strict;
use 5.010;

use Scalar::Util   ();
use HTML::Entities ();

use Wikifier::Utilities qw(safe_name trim);

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
# $careful prevents recursion
# don't use it directly
#
sub parse_formatted_text {
    my ($wikifier, $page, $text, $no_html_entities, $careful) = @_;
    my @items;
    my $string = '';

    my $last_char    = '';   # the last parsed character.
    my $in_format    = 0;    # inside a formatting element.
    my $format_type  = '';   # format name such as 'i' or '/b'
    my $escaped      = 0;    # this character was escaped.
    my $next_escaped = 0;    # the next character will be escaped.

    # parse character-by-character.
    CHAR: foreach my $char (split '', $text) {
        $next_escaped = 0;
        given ($char) {

        # escapes.
        when ('\\') {
            continue if $escaped; # this backslash was escaped.
            $next_escaped = 1;
        }

        # [ marks the beginning of a formatting element.
        when ('[') {
            continue if $escaped;

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
            if (defined $string) {
                push @items, [ $no_html_entities, $string ];
                $string = '';
            }

        }

        # ] marks the end of a formatting element.
        when (']') {
            continue if $escaped;

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
                    $wikifier->parse_format_type($page, $format_type, $careful)
                ];
                $in_format = 0;
            }

        }

        # any other character.
        default {

            # if we're in the format type, append to it.
            if ($in_format) {
                $format_type .= $char;
            }

            # it's any regular character, either within or outside of a format.
            else {
                $string .= $char;
            }

        }

        } # end of switch

        # set last character and escape for next character.
        $last_char = $char;
        $escaped   = $next_escaped;

    }

    # final string item.
    push @items, [ $no_html_entities, $string] if length $string;

    # join them together, adding HTML entities when necessary.
    return join '', map {
        my ($fmtd, $value) = @$_;
        $fmtd ? $value : HTML::Entities::encode($value)
    } @items;
}

# parses an individual format type, aka the content in [brackets].
# for example, 'i' for italic. returns the string generated from it.
sub parse_format_type {
    my ($wikifier, $page, $type, $careful) = @_;

    given ($type) {

    # italic, bold, strikethrough.
    when ('i') { return '<span style="font-style: italic;">'            }
    when ('b') { return '<span style="font-weight: bold;">'             }
    when ('s') { return '<span style="text-decoration: line-through;">' }
    when ('^') { return '<sup>'                                         }
    when (['/s', '/b', '/i']) { return '</span>' }

    # inline quote.
    when ( 'q') { return '"<span style="font-style: italic;">'  }
    when ('/q') { return '</span>"'                             }
    when ('/^') { return '</sup>'                               }

    # generic end span.
    when ('/') { return '</span>' }

    # new line.
    when (['nl', 'br']) { return '<br />' }

    # dashes.
    when ('--')  { return '&ndash;' }
    when ('---') { return '&mdash;' }

    # interpolable variable.
    when ($_ =~ /^%([\w.]+)$/ && !$careful) {
        my $var = $page->get($1);
        return defined $var ?
            $wikifier->parse_formatted_text($page, $var, 0, 1) : '(null)';
    }

    # variable.
    when (/^@([\w.]+)$/) {
        my $var = $page->get($1);
        return defined $var ? $var : '(null)';
    }

    # html entity.
    when (/^&(.+)$/) {
        return "&$1;";
    }

    # a link in the form of [[link]], [!link!], or [$link$]
    when (/^([\!\[\$\~]+?)(.+)([\!\]\$\~]+?)$/) { # inner match should be most greedy.

        my ($link_char, $inner, $link_type) = (trim($1), trim($2));
        my ($target, $text, $title) = ($inner, $inner, '');

        # format is <text>|<target>
        if ($inner =~ m/^(.+?)\|(.+)$/) {
            $text   = trim($1);
            $target = trim($2);
        }

        # internal wiki link [[article]]
        if ($link_char eq '[') {
            $link_type = 'internal';
            $title     = ucfirst $target;
            $target    = $page->wiki_opt('root.page').'/'.safe_name($target, 1);
        }

        # category wiki link [~category~]
        elsif ($link_char eq '~') {
            $link_type = 'category';
            $title     = ucfirst $target;
            $target    = $page->wiki_opt('root.category').'/'.safe_name($target, 1);
        }

        # external wiki link [!article!]
        elsif ($link_char eq '!') {
            $link_type = 'external';
            $title     = $page->wiki_opt('external.name').': '.ucfirst($target);
            $target    = $page->wiki_opt('external.root').'/'.safe_name($target);
        }

        # other non-wiki link [$url$]
        elsif ($link_char eq '$') {
            $link_type = 'other';
            $title     = 'External link';
        }

        $title = qq( title="$title") if $title;
        return qq{<a class="wiki-link-$link_type" href="$target"$title>$text</a>};
    }

    # fake references.
    when ('ref') {
        $page->{reference_number} ||= 1;
        my $ref = $page->{reference_number}++;
        return qq{<sup style="font-size: 75%"><a href="#">[$ref]</a></sup>};
    }

    # colors.
    when (exists $colors{ +lc }) {
        my $color = $colors{ +lc };
        return "<span style=\"color: $color;\">";
    }

    # real references.
    when (\&Scalar::Util::looks_like_number) {
        return qq{<sup style="font-size: 75%"><a href="#wiki-ref-$type">[$type]</a></sup>};
    }

    } # end switch

    # leave out anything else, I guess.
    return q..;

}

1
