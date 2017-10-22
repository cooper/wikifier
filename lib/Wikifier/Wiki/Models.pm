# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use HTTP::Date qw(time2str);
use Wikifier::Utilities qw(page_name page_name_ne align L Lindent back);
use Scalar::Util qw(blessed);
use JSON::XS ();

my $json = JSON::XS->new->pretty->convert_blessed;

##############
### MODELS ###
##############

# create a page object with this wiki
sub model_named {
    my ($wiki, $name, %opts) = @_;
    (my $no_ext_name = $name) =~ s/\.page$//;
    my $page = Wikifier::Page->new(
        is_model   => 1,
        file_path  => $wiki->path_for_model($name),
        name       => page_name($name, '.model'),
        model_name => page_name_ne($name),
        #wikifier   => $page->wikifier, FIXME?
        wiki       => $wiki,
        %opts
    );
    return $page;
}

# Displays a model.
sub display_model {
    my ($wiki, $page_name) = (shift, shift);
    my $page = $page_name if blessed $page_name;
    $page_name = page_name($page_name);
    Lindent "($page_name)";
        my $result = $wiki->_display_model($page_name, @_);
        $page->{recent_result} = $result if $page;
    back;
    return $result;
}
sub _display_model {
    my ($wiki, $page_name) = @_;
    my $result = {};

    # create a page object
    my $page = $wiki->model_named($page_name);
    $result->{page} = $page;

    # get page info
    $page_name = $page->name;
    my $path   = $page->path;

    # file does not exist.
    return display_error("Model does not exist.")
        if !-f $path;

    # set path, file, and meme type.
    $result->{file} = $page_name;
    $result->{path} = $path;
    $result->{mime} = 'text/html';

    # parse the model.
    # if an error occurs, parse it again in variable-only mode.
    # then hopefully we can at least get the metadata and categories.
    my $err = $page->parse;
    if ($err) {
        $page->{vars_only}++;
        $page->parse;
        $wiki->cat_add_page($page, 'models', cat_type => 'data');
        return display_error($err, parse_error => 1);
    }

    # extract warnings from parser info
    $result->{warnings} = $page->{warnings};

    # update models category
    $wiki->cat_add_page($page, 'models', cat_type => 'data');

    # if this is a draft, pretend it doesn't exist.
    if ($page->get('page.draft')) {
        L 'Draft';
        return display_error(
            "Model has not yet been published.",
            draft => 1
        );
    }

    # generate the HTML and headers.
    $result->{type}       = 'model';
    $result->{content}    = $page->html;
    $result->{css}        = $page->css;
    $result->{generated}  = \1;
    $result->{modified}   = time2str(time);
    $result->{mod_unix}   = time;
    $result->{categories} = [ _cats_to_list($page->{categories}) ];

    # model metadata category
    $wiki->cat_add_page(undef, $page->name,
        cat_type        => 'model',
        cat_extras      => { model_name => $page->page_info }, # model metadata
        create_ok       => 1,                   # allow prefix to be created
        preserve        => \1,                  # keep the cat until model delete
        force_update    => 1                    # always rewrite model metadata
    );

    return $result;
}

# Displays the wikifier code for a model.
# display_model = 1  also include ->display_model result, omitting  {content}
# display_model = 2  also include ->display_model result, including {content}
sub display_model_code {
    my ($wiki, $page_name) = (shift, shift);
    my $page = $page_name if blessed $page_name;
    $page_name = page_name($page_name);
    Lindent "($page_name)";
        my $result = $wiki->_display_model_code($page_name, @_);
    back;
    return $result;
}
sub _display_model_code {
    my ($wiki, $page_name, $display_model) = @_;
    $page_name = page_name($page_name);
    my $path   = $wiki->path_for_model($page_name);
    my $result = {};

    # file does not exist.
    if (!-f $path) {
        return display_error("Model does not exist.");
    }

    # read.
    my $code = file_contents($path);
    if (!defined $code) {
        return display_error("Failed to read model.");
    }

    # set path, file, and meme type.
    $result->{file}     = $page_name;
    $result->{path}     = $path;
    $result->{mime}     = 'text/plain';
    $result->{type}     = 'model_code';
    $result->{content}  = $code;

    # we might want to also call ->display_model(). this would be useful
    # for determining where errors occur on the page.
    if ($display_model) {
        my %model_res_copy = %{ $wiki->display_model($page_name) };
        delete $model_res_copy{content}
            unless $display_model == 2;
        $result->{display_result} = \%model_res_copy;
    }

    return $result;
}

sub get_model {
    my ($wiki, $filename, $create_ok) = @_;
    my $path = $wiki->path_for_model($filename, $create_ok);
    my $cat_path = $wiki->path_for_category($filename, 'model');

    # neither the model nor a category for it exist. this is a ghost
    return if !-f $path && (!defined $cat_path || !-f $cat_path);

    # basic info available for all models
    my @stat = stat $path; # might be empty
    my $model_data = {
        file        => $filename,
        created     => $stat[10],   # ctime, probably overwritten
        mod_unix    => $stat[9]     # mtime, probably overwritten
    };

    # from this point on, we need the category
    return $model_data unless -f $cat_path;

    # it exists; let's see what's inside.
    my %cat = hash_maybe eval { $json->decode(file_contents($cat_path)) };
    %cat    = hash_maybe $cat{model_info};
    return $model_data if !scalar keys %cat;
    
    # inject metadata from category
    @$model_data{ keys %cat } = values %cat;
    $model_data->{title} //= $model_data->{file};
    
    return $model_data;
}

sub get_models {
    my ($wiki, %models) = shift;
    my @cat_names = map substr($_, 0, -4), $wiki->all_categories('model');
    
    # models without category files will be skipped.
    foreach my $filename (@cat_names, $wiki->all_models) {
        next if $models{$filename};
        my $model_data = $wiki->get_model($filename, 1) or next;
        $filename = $model_data->{file};
        $models{$filename} = $model_data;
    }
    
    return \%models;
}

1
