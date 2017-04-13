# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use Wikifier::Utilities qw(Lindent back);
use Cwd qw(abs_path);

# all markdown files
sub all_markdowns {
    my $wiki = shift;
    my $dir = $wiki->opt('dir.md');
    return if !length $dir;
    return unique_files_in_dir($dir, 'md');
}

sub display_markdown {
    my ($wiki, $md_name) = (shift, @_);
    Lindent "($md_name)";
    my $ret = $wiki->_display_markdown(@_);
    back;
    return $ret;
}

sub _display_markdown {
    my ($wiki, $md_name, %opts) = @_;
    my $md_path   = abs_path($wiki->opt('dir.md')."/$md_name");
    my $page_path = $wiki->path_for_page($md_name);
    
    # no such markdown file
    return display_error('Markdown file does not exist.')
        if !-f $md_path;
        
    # no markdown package
    return display_error('Markdown generator is unavailable.')
        if !eval { require Text::Markdown };
        
    # filename and path info
    my $result = {};
    $result->{file} = $md_name;         # with extension
    $result->{name} = (my $md_name_ne = $md_name) =~ s/\.md$//; # without
    $result->{path} = $page_path;       # absolute path
    
    # page content
    $result->{type} = 'markdown';
    $result->{mime} = 'text/html';
    
    # slurp the markdown text
    my $text = file_contents($md_path);
    
    # generate the html
    my $m = Text::Markdown->new;
    my $html = $m->markdown($text);
    
    # write to file
    open my $fh, '>', $page_path
        or return display_error('Unable to write page file.');
    
    print $fh $html;
    close $fh;
    
    return $result;
}

1
