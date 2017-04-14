# Copyright (c) 2017, Mitchell Cooper
#
# Wikifier::Page provides an objective interface to a wiki page or article. It
# implements the most bsaic user-friendly programming interface of the wikifier.
#
package Wikifier::Page;

use warnings;
use strict;
use 5.010;
use Scalar::Util qw(blessed looks_like_number);
use File::Basename qw(basename);
use Cwd qw(abs_path);
use HTML::Strip;
use Wikifier::Utilities qw(
    L align page_name page_name_ne trim
    no_length_undef filter_nonempty
);

my $stripper = HTML::Strip->new(emit_spaces => 0);

# default options.
our %wiki_defaults = (
    'name'                  => 'Wiki',
    'dir.wikifier'          => '.',
    'dir.image'             => 'images',
    'dir.page'              => 'pages',
    'dir.cache'             => 'cache',
    'dir.model'             => 'models',
    'dir.category'          => 'categories',
    'root.image'            => '/images',
    'root.category'         => '/topic',
    'root.page'             => '/page',
    'root.wiki'             => '',          # AKA "/"
    'image.size_method'     => 'javascript',
    'page.enable.title'     => 1,
    'external.wp.name'      => 'Wikipedia',
    'external.wp.root'      => 'http://en.wikipedia.org/wiki',
    'external.wp.type'      => 'mediawiki',
    'image.rounding'        => 'normal',
    'image.calc'            => \&_default_calculator,
    'image.sizer'           => \&_default_sizer,
    'var'                   => {}
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

    # if file_path is provided, we can use it for the page name
    if (length $opts{file_path} && !length $opts{name}) {
        $opts{name} = basename($opts{file_path});
    }

    # create the page.
    my $page = bless \%opts, $class;
    $page->{name} = page_name($page->{name});

    # create the page's main block.
    $page->{main_block} = $wikifier->{main_block} = $wikifier->create_block(
        line   => 1,
        wdir   => $page->{wdir} // $page->wiki_opt('dir.wikifier'),
        type   => 'main',
        parent => undef     # main block has no parent.
    );

    return $page;
}

# parses the file.
sub parse {
    my $page = shift;
    my ($err, $c);
    L align('Parse'.($page->{vars_only} ? ' (vars only)' : '')), sub {
        ($err, $c) = $page->wikifier->parse($page);
    };
    L align('Error', $err) if $err;
    return wantarray ? ($err, $c) : $err;
}

# returns the generated page HTML.
sub html {
    my $page = shift;
    
    # generate HTML
    my $res;
    L('HTML',     sub { $res = $page->{wikifier}{main_block}->html($page)   });
    L('Generate', sub { $res = $res->generate                               });
    
    # remove indentations on things marked for no indentation
    $res =~ s/(\n)(\s*)\t\t\t/$1/g;
    
    return $res;
}

# returns the generated page CSS.
sub css {
    my $page = shift;
    return unless $page->{styles};
    my $string = '';
    foreach my $rule_set (@{ $page->{styles} }) {
        my $apply_to = $page->_css_apply_string(@{ $rule_set->{apply_to} });
        $string     .= "$apply_to {\n";
        foreach my $rule (keys %{ $rule_set->{rules} }) {
            my $value = $rule_set->{rules}{$rule};
            $string  .= "    $rule: $value;\n";
        }
        $string .= "}\n";
    }
    return $string;
}

sub _css_apply_string {
    my ($page, @sets) = @_;
    # @sets = an array of [
    #   ['section'],
    #   ['.someClass'],
    #   ['section', '.someClass'],
    #   ['section', '.someClass.someOther']
    # ] etc.
    return join ",\n", map {
        my $string = $page->_css_set_string(@$_);
        my $start  = substr $string, 0, 10;
        if (!$start || $start ne '.wiki-main') {
            my $id  = $page->{wikifier}{main_block}{element}{id};
            $string = ".wiki-$id $string";
        }
        $string
    } @sets;
}

sub _css_set_string {
    my ($page, @items) = @_;
    return join ' ', map { $page->_css_item_string(split //, $_) } @items;
}

sub _css_item_string {
    my ($page, @chars) = @_;
    my ($string, $in_class, $in_id, $in_el_type) = '';
    foreach my $char (@chars) {

        # we're starting a class.
        if ($char eq '.') {
            $in_class++;
            $string .= '.wiki-class-';
            next;
        }

        # we're starting an ID.
        if ($char eq '#') {
            $in_id++;
            $string .= '.wiki-id-';
            next;
        }

        # we're in neither a class nor an element type.
        # assume that this is the start of element type.
        if (!$in_class && !$in_id && !$in_el_type && $char ne '*') {
            $in_el_type = 1;
            $string .= '.wiki-';
        }

        $string .= $char;
    }
    return $string;
}

# set a variable. returns new value
sub set {
    my ($page, $var, $value) = @_;
    return ($page->set_with_err($var, $value))[0];
}

# set a variable. returns (new value, error)
sub set_with_err {
    my ($page, $var, $value) = @_;
    my ($new_val, $err) = _set_var($page, $page->{variables}, $var, $value);
    $page->warning($err) if $err;
    return ($new_val, $err);
}

# fetch a variable. returns value
sub get {
    my ($page, $var) = @_;
    return ($page->get_with_err($var))[0];
}

# fetch a variable. returns (value, error)
sub get_with_err {
    my ($page, $var)  = @_;

    # try page variables.
    my ($found, $err) = _get_var($page->{variables}, $var);
    $page->warning($err) if $err;
    return ($found, $err) if defined $found || $err;

    # try global variables.
    ($found, $err) = _get_var($page->{wiki}{variables}, $var) if $page->{wiki};
    $page->warning($err) if $err;
    return ($found, $err) if defined $found || $err;

    return (undef, undef);
}

# fetch a variable yielding a hash.
sub get_hash {
    my $val = &get_href;
    return %$val;
}

# fetch a variable yielding a hashref.
# returns empty hashref if not found.
sub get_href {
    my $val = &get;
    $val = $val->to_data if blessed $val && $val->can('to_data');
    return {} if ref $val ne 'HASH';
    return $val;
}

# fetch a variable yielding a list.
sub get_array {
    my $val = &get_aref;
    return @$val;
}

# fetch a variable yielding an arrayref.
# returns empty arrayref if not found.
sub get_aref {
    my $val = &get;
    $val = $val->to_data if blessed $val && $val->can('to_data');
    return [] if ref $val ne 'ARRAY';
    return $val;
}

# fetch a variable from $where. returns (value, error)
sub _get_var {
    my ($where, $var) = @_;
    my @parts = split /\./, $var;
    while (length($var = shift @parts)) {
        ($where, my $err) = _get_attr($where, $var);
        return (undef, $err) if $err;
    }
    return $where;
}

# fetch an attribute from $where. returns (value, error)
sub _get_attr {
    my ($where, $attr) = @_;
    return undef if !defined $where;
    my $desc = $where;

    # it's an object. hopefully it can ->get_attribute or ->to_data
    if (blessed $where) {
        $desc = $where->hr_desc if $where->can('hr_desc');
        if ($where->can('get_attribute')) {
            return $where->get_attribute($attr);
        }
        elsif ($where->can('to_data')) {
            $where = $where->to_data;
        }
        else {
            return (undef,
                "Attempted to fetch \@$attr from $desc ".
                'which does not support attributes'
            );
        }
    }

    # hash ref
    if (ref $where eq 'HASH') {
        return $where->{$attr};
    }

    # array ref
    if (ref $where eq 'ARRAY') {
        return (undef,
            "Attempted to fetch \@$attr from $desc ".
            'which only supports numeric indices'
        ) if !looks_like_number($attr);
        return $where->[$attr];
    }

    # something else
    return (undef, "Not sure how to fetch \@$attr from ".($desc // '(undef)'));
}

# set a variable on $where. returns (new value, error)
sub _set_var {
    my ($page, $where, $var, $value) = @_;
    my @parts   = split /\./, $var;
    my $setting = pop @parts;
    while (length($var = shift @parts)) {
        my ($new_where, $err) = _get_attr($where, $var);
        return (undef, $err) if $err;

        # this location doesn't exist, so make a new map
        if (!$new_where) {
            my $c = $page->{main_block}{current};
            $new_where = $page->wikifier->create_block(
                type    => 'map',
                current => $c,
                line    => $c->{line},
                col     => $c->{col},
                parent  => $page->{main_block}
            );
            _set_attr($where, $var, $new_where);
        }

        $where = $new_where;
    }
    return _set_attr($where, $setting, $value);
}

# set an attribute on $where. returns (new value, error)
sub _set_attr {
    my ($where, $attr, $value) = @_;
    return undef if !defined $where;
    my $desc = $where;

    # it's an object. hopefully it can ->set_attribute or ->to_data
    if (blessed $where) {
        $desc = $where->hr_desc if $where->can('hr_desc');
        if ($where->can('set_attribute')) {
            return $where->set_attribute($attr, $value);
        }
        elsif ($where->can('to_data')) {
            $where = $where->to_data;
        }
        else {
            return (undef,
                "Attempted to assign \@$attr on $desc ".
                'which does not support attribute assignment'
            );
        }
    }

    # hash ref
    if (ref $where eq 'HASH') {
        return $where->{$attr} = $value;
    }

    # array ref
    if (ref $where eq 'ARRAY') {
        return (undef,
            "Attempted to set \@$attr on $desc ".
            'which only supports numeric indices'
        ) if !looks_like_number($attr);
        return $where->[$attr] = $value;
    }

    # something else
    return (undef, "Not sure how to assign \@$attr on ".($desc // '(undef)'));
}

# returns HTML for formatting.
sub parse_formatted_text {
    my $page = shift;
    return $page->wikifier->parse_formatted_text($page, @_);
}

# returns a wiki option or the default.
sub wiki_opt {
    my ($page, $var, @args) = @_;
    return $page->{wiki}->opt($var, @args) if blessed $page->{wiki};
    return _call_wiki_opt(
        $page->{opts}{$var} // $wiki_defaults{$var},
        @args
    );
}

# returns the variable defined on the page if available; otherwise
# falls back to the wiki option or its default.
sub page_opt {
    my ($page, $var, @args) = @_;

    # first see if the page variable exists
    my $val = $page->get($var);

    # use $wiki->opt if there is a wiki
    if (!defined $val && blessed $page->{wiki}) {
        return $page->{wiki}->opt($var, @args);
    }

    # still nothing?
    $val //= $page->{opts}{$var};   # opts => { ... } in the page constructor
    $val //= $wiki_defaults{$var};  # default options as a last resort

    return _call_wiki_opt($val, @args);
}

sub _call_wiki_opt {
    my ($val, @args) = @_;
    if (ref $val eq 'CODE') {
        return $val->(@args);
    }
    return $val;
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
        $final_h = $img{page}->_image_round($big_h / $scale_factor);
    }

    # height was given; calculate width.
    elsif ($height) {
        $scale_factor = $big_h / $height;
        $final_w = $img{page}->_image_round($big_w / $scale_factor);
        $final_h = $img{height};
    }

    return ($final_w, $final_h);
}

sub _default_sizer {
    my %img = @_;
    my $page = $img{page};

    # full-size image.
    if (!$img{width} || !$img{height}) {
        return $page->wiki_opt('root.image').'/'.$img{file};
    }

    # scaled image.
    return $page->wiki_opt('root.image')."/$img{width}x$img{height}-$img{file}";
}

# round dimension according to setting.
sub _image_round {
    my ($page, $size) = @_;
    my $round = $page->wiki_opt('image.rounding');
    return int($size + 0.5 ) if $round eq 'normal';
    return int($size + 0.99) if $round eq 'up';
    return int($size       ) if $round eq 'down';
    return $size; # fallback.
}

# page filename, with or without extension.
# this DOES take symbolic links into account.
sub name {
    my $page = shift;
    return $page->{abs_name} //= do {
        my $dir  = $page->wiki_opt('dir.page');
        my $path = $page->path;
        (my $name = $path) =~ s/^\Q$dir\E//;
        index($path, $dir) ? basename($page->path) : $name;
    };
}
sub name_ne {
    my $page = shift;
    return page_name_ne($page->name);
}

# absolute path to page
sub path {
    my $page = shift;
    return $page->{abs_path} //= abs_path($page->rel_path);
}

# unresolved page filename, with or without extension.
# this does NOT take symbolic links into account.
sub rel_name {
    my $page = shift;
    return $page->{name};
}
sub rel_name_ne {
    my $page = shift;
    return page_name_ne($page->rel_name);
}

# unresolved path to page
sub rel_path {
    my $page = shift;
    return $page->{file_path}
        if length $page->{file_path};
    return $page->wiki_opt('dir.page').'/'.$page->rel_name;
}

# location to which this page redirects, if any, undef otherwise.
# this may be a relative or absolute URL, suitable for use in a Location header.
sub redirect {
    my $page = shift;
    
    # symbolic link redirect
    if (-l $page->rel_path) {
        return $page->wiki_opt('root.page').'/'.$page->name_ne;
    }
    
    # @page.redirect
    if (my $link = $page->get('page.redirect')) {
        my ($ok, $target) = $page->wikifier->parse_link($page, $link);
        return $target if $ok;
    }

    return undef;
}

# page creation time from @page.created
sub created {
    my $page = shift;
    my $created = trim $page->get('page.created');
    return undef if !length $created || $created =~ m/\D/;
    return $created + 0;
}

# page modification time from stat()
sub modified {
    my $page = shift;
    return (stat $page->path)[9];
}

# absolute path to cache file
sub cache_path {
    my $page = shift;
    return abs_path($page->{cache_path})
        if length $page->{cache_path};
    return $page->{abs_cache_path} //= abs_path(
        $page->wiki_opt('dir.cache').'/'.$page->name.'.cache'
    );
}

# cache file modification time from stat()
sub cache_modified {
    my $page = shift;
    return (stat $page->cache_path)[9];
}

# absolute path to search text file
sub search_path {
    my $page = shift;
    return abs_path($page->{search_path})
        if length $page->{search_path};
    return $page->{abs_search_path} //= abs_path(
        $page->wiki_opt('dir.cache').'/'.$page->name.'.txt'
    );
}

# page info to be used in results, stored in cats/cache files
sub page_info {
    my $page = shift;
    return filter_nonempty {
        mod_unix    => $page->modified,
        created     => $page->created,
        draft       => $page->draft,
        redirect    => $page->redirect,
        fmt_title   => $page->fmt_title,
        title       => $page->title,
        author      => $page->author
    };
}

# page draft from @page.draft
sub draft {
    my $page = shift;
    return !!$page->get('page.draft');
}

# page author from @page.author
sub author {
    my $page = shift;
    return no_length_undef trim $page->get('page.author');
}

# formatted title from @page.title
sub fmt_title {
    my $page = shift;
    return no_length_undef trim $page->get('page.title');
}

# tag-stripped version of page title
sub title {
    my $page = shift;
    my $title = $page->fmt_title;
    return length $title ? $stripper->parse($title) : undef;
}

# title if available; otherwise filename
sub title_or_name {
    my $page = shift;
    return $page->title // $page->name;
}

# get position
sub pos : method {
    my $page = shift;
    state $zeropos = { line => 0, col => 0 };
    my $block = $page->{main_block} or return $zeropos;
    my $c     = $block->{current}   or return $zeropos;
    return {
        line    => $c->{line},
        col     => $c->{col}
    };
}

# parser warning
sub warning {
    my ($page, $pos, $warn) = @_;
    my $block = $page->{main_block} or return;
    my $c     = $block->{current}   or return;
    if (!defined $warn) {
        $warn = $pos;
    }
    else {
        $c->{temp_line} = $pos->{line};
        $c->{temp_col}  = $pos->{col};
    }
    $c->warning($warn);
}

sub wikifier { shift->{wikifier} }

1
