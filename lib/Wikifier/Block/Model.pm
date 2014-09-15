#
# Copyright (c) 2014, Mitchell Cooper
#
package Wikifier::Block::Model;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    model => {
        base   => 'hash',
        parse  => \&model_parse,
        html   => \&model_html
    }
);

sub model_parse {
    my ($block, $page) = @_;
    
    # parse the hash.
    $block->parse_base(@_[1..$#_]);

    # create a page.
    my $name  = Wikifier::Utilities::safe_name($block->{name});
    my $path  = Cwd::abs_path($page->wiki_opt('dir.model').q(/).$name);
    my $model = $block->{model} = Wikifier::Page->new(
        file      => $path,
        name      => "$name.page",
        mode_name => $name,
        wikifier  => $page->wikifier,
        vars_only => 1
    );
    
    # parse the page.
    $model->parse;
    
}

sub model_html {
    my ($block, $page, $el) = @_;
    my $model   = $block->{model} or return;
    my $main_el = $model->{wikifier}{main_block}{element};
    
    # change the class from 'main' to 'model'
    $main_el->remove_class('main');
    $main_el->add_class('model');
    $main_el->add_class("model-$$model{model_name}");
    
    # inject it into $el.
    %$el = %$main_el;
    
}

__PACKAGE__
