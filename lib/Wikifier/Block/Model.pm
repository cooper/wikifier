# Copyright (c) 2017, Mitchell Cooper
#
package Wikifier::Block::Model;

use warnings;
use strict;

use Cwd qw(abs_path);
use Wikifier::Utilities qw(page_name);

our %block_types = (
    model => {
        base   => 'map',
        parse  => \&model_parse,
        html   => \&model_html,
        title  => 1
    }
);

sub model_parse {
    my ($block, $page) = (shift, @_);

    # parse the hash
    $block->parse_base(@_);

    # remember that the page uses this model
    my $name = $block->name;
    my $file = page_name($name, '.model');
    $page->{models}{$file}++;

    # create a page
    my $path  = abs_path($page->opt('dir.model')."/$file");
    my $model = $block->{model} = Wikifier::Page->new(
        is_model   => 1,
        file_path  => $path,
        name       => $file,
        model_name => $name,
        #wikifier   => $page->wikifier,
        wiki       => $page->{wiki}, # (might not exist)
        variables  => { 'm' => $block->{map_hash} }
    );

    # check if it exists before anything else
    if (!-e $model->path) {
        $block->warning("Model \$$name\{} does not exist");
        return;
    }

    # parse the page.
    my $err = $model->parse;
    $block->warning("Model \$$name\{} error: $err") if $err;
    
    # determine whether to include model tags
    $block->{include_tags} = $model->get('model.tags');
}

sub model_html {
    my ($block, $page, $model_el) = (shift, @_);
    my $model      = $block->{model} or return;
    my $main_block = $model->{wikifier}{main_block} or return;

    $block->html_base($page); # call hash html.

    # generate the DOM
    my $el = $main_block->html($model) or return;

    # add the main page element to our element.
    $el->remove_class('main');
    $el->add_class('model');
    $el->add_class("model-$$model{model_name}");
    $el->add_class($model_el->{id});

    # disable tags
    $el->configure(no_tags => 1) unless $block->{include_tags};

    # overwrite the model element
    $block->{element} = $el;
}

__PACKAGE__
