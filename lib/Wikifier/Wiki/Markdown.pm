# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.014; # for /u

use CommonMark qw(:node :event :list);
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;
use Wikifier::Utilities qw(
    E Lindent back align make_dir
    page_name page_name_link
);

my $punctuation_re  = qr/[^\p{Word}\- ]/u;
my $table_re        = qr/ *\|(.+)\n *\|( *[-:]+[-| :]*)\n((?: *\|.*(?:\n|$))*)\n*/;
my $np_table_re     = qr/ *(\S.*\|.*)\n *([-:]+ *\|[-| :]*)\n((?:.*\|.*(?:\n|$))*)\n*/;

sub convert_markdown {
    my ($wiki, $md_name) = (shift, @_);
    Lindent "($md_name)";
        my $result = $wiki->_convert_markdown(@_);
    back;
    return $result;
}

sub _convert_markdown {
    my ($wiki, $md_name, %opts) = @_;
    my $md_path = abs_path($wiki->opt('dir.md')."/$md_name");
    
    # no such markdown file
    return display_error('Markdown file does not exist.')
        if !-f $md_path;
        

    (my $md_name_ne = $md_name) =~ s/\.md$//;
    $md_name_ne   = page_name_link($md_name_ne);
    my $page_name = page_name($md_name_ne);

    # $page_path_cache is the true target in the cache
    # $page_path is where we will symlink to
    my $page_dir  = $wiki->opt('dir.page');
    my $cache_dir = $wiki->opt('dir.cache').'/md';
    make_dir($page_dir,  $md_name_ne);
    make_dir($cache_dir, $md_name_ne);
    my $page_path       = "$page_dir/$page_name";
    my $page_path_cache = "$cache_dir/$page_name";
        
    # filename and path info
    my $result = {};
    $result->{file} = $md_name;         # with extension
    $result->{name} = $md_name_ne;      # without extension
    $result->{path} = $page_path_cache;   # absolute path to page
    
    # page content
    $result->{type} = 'markdown';
    $result->{mime} = 'text/plain'; # wikifier language
    
    # slurp the markdown file
    my $md_text = file_contents($md_path);
    $md_text =~ s/(\n)(\s*)\t/$1$2    /g;   # unindent code and html blocks
    $md_text =~ s/\xa0/ /g;                 # replace non-breaking space

    # generate the wiki source
    my $source = $wiki->_generate_from_markdown($md_name, $md_text, %opts);
    $result->{content} = $source;
    
    # page exists here already
    if (-e $page_path) {
        my $page = Wikifier::Page->new(
            file_path => $page_path,
            vars_only => 1
        );
        $page->parse;
        if (!$page->generated) {
            return display_error('Target page exists.');
        }
    }
    
    # write to file
    open my $fh, '>', $page_path_cache
        or return display_error('Unable to write page file.');
    print $fh $source;
    close $fh;
    
    # symlink real page to generated page in cache
    my ($prefix, $page_basename) = fileparse($page_name);
    symlink File::Spec->abs2rel($page_path_cache, dirname($page_path)),
        $page_path;

    return $result;
}

my %es = (
    EVENT_ENTER , 'ENTER',
    EVENT_EXIT  , 'EXIT ',
    EVENT_DONE  , 'DONE '
);

# FIXME: I bet the $current_text doesn't work right when mixed with other nodes

sub _generate_from_markdown {
    my ($wiki, $md_name, $md_text, %opts) = @_;
    my $source = '';
    my $indent = 0;
    my $header_level = 0;
    my $current_text = '';
    my $page_title;
    
    # before anything else, convert GFM tables to HTML
    $md_text = $wiki->_md_table_replace($md_text);
    
    my $add_text = sub {
        my $text = shift;
        foreach my $line (split /(\n)/, $text, -1) {
            $source .= $line;
            $source .= ('    ' x $indent) if $line eq "\n";
        }
    };
    
    # parse the markdown file
    my $doc = CommonMark->parse(string => $md_text);
    
    # iterate through nodes
    my $iter = $doc->iterator;
    while (my ($ev_type, $node) = $iter->next) {
        my $node_type = $node->get_type;
        
        # NODE_TEXT
        # plain text
        if ($node_type == NODE_TEXT) {
            my $text = md_escape_fmt($node->get_literal);
            $page_title = $text if !length $page_title && $header_level;
            if (defined $current_text) {
                $current_text .= $text;
            }
            else {
                $add_text->($text);
            }
        }
        
        # NODE_HEADING
        # heading
        elsif ($node_type == NODE_HEADING) {
            
            # entering the header
            if ($ev_type == EVENT_ENTER) {
                
                # if we already have a header of this level open, this
                # terminates it. if we have a header of a lower level (higher
                # number) open, this terminates it and all others up to the
                # biggest level.
                my $level = $node->get_header_level;
                if ($level <= $header_level) {
                    $indent--, $add_text->("\n}\n") for $level..$header_level;
                }
                
                # e.g. going from # to ###
                if ($level > $header_level + 1) {
                    $indent++, $add_text->("~sec {\n") for ($header_level + 2)..$level;
                }
                
                $header_level = $level;
                $add_text->("~sec [");
                $current_text = '';
            }
            
            # closing the header starts the section block
            else {
                $indent++;
                $add_text->("$current_text] {\n");
                
                # figure the anchor. modeled after what github uses:
                # https://github.com/jch/html-pipeline/blob/master/lib/html/pipeline/toc_filter.rb
                # the -n suffixes are added automatically as needed in Section.pm
                my $section_id = $current_text;
                $section_id =~ tr/A-Z/a-z/;                 # ASCII downcase
                $section_id =~ s/$punctuation_re//g;        # remove punctuation
                $section_id =~ s/ /-/g;                     # replace spaces with dashes
                $section_id = md_escape_fmt($section_id);
                $add_text->("meta { section: $section_id; }\n");
                undef $current_text;
            }
        }
        
        # NODE_PARAGRAPH
        # paragraph
        elsif ($node_type == NODE_PARAGRAPH) {
            if ($ev_type == EVENT_ENTER) {
                $indent++;
                $add_text->("~p {\n");
            }
            else {
                $indent--;
                $add_text->("\n}\n");
            }
        }
        
        # NODE_SOFTBREAK
        # soft line break
        elsif ($node_type == NODE_SOFTBREAK) {
            $add_text->("\n");
        }
        
        # NODE_LINEBREAK
        # hard line break
        elsif ($node_type == NODE_LINEBREAK) {
            $add_text->("[nl]");
        }
        
        # NODE_LIST
        elsif ($node_type == NODE_LIST) {
            if ($ev_type == EVENT_ENTER) {
                # TODO: respect list type $node->get_list_type
                $indent++;
                $add_text->("~list {\n");
            }
            else {
                $indent--;
                $add_text->("\n}\n");
            }
        }
        
        # NODE_ITEM
        elsif ($node_type == NODE_ITEM) {
            if ($ev_type == EVENT_EXIT) {
                $add_text->(";\n");
            }
        }
    
        # NODE_EMPH
        elsif ($node_type == NODE_EMPH) {
            if ($ev_type == EVENT_ENTER) {
                $add_text->('[i]');
            }
            else {
                $add_text->('[/i]');
            }
        }
        
        # NODE_STRONG
        elsif ($node_type == NODE_STRONG) {
            if ($ev_type == EVENT_ENTER) {
                $add_text->('[b]');
            }
            else {
                $add_text->('[/b]');
            }
        }
        
        # NODE_LINK
        elsif ($node_type == NODE_LINK) {
            if ($ev_type == EVENT_ENTER) {
                $add_text->('[[ ')
            }
            else {
                my $url = $node->get_url;
                $url =~ s/\.md(\s*#?.*)$/$1/; # FIXME: relative links only
                $add_text->(" | $url ]]");
            }
        }
        
        # NODE_IMAGE
        elsif ($node_type == NODE_IMAGE) {
            if ($ev_type == EVENT_ENTER) {
                my $src = $node->get_url;
                $add_text->("~image {\n    file: $src;\n    alt: ");
                $current_text = '';
            }
            else {
                $add_text->(md_escape_fmt($current_text).";\n}\n");
                undef $current_text;
            }
        }
        
        # NODE_CODE
        elsif ($node_type == NODE_CODE) {
            my $code = md_escape_fmt($node->get_literal);
            $add_text->("[c]$code\[/c]");
        }
        
        # NODE_CODE_BLOCK
        elsif ($node_type == NODE_CODE_BLOCK) {
            my $code = md_escape($node->get_literal);
            my $lang = $node->get_fence_info;
            $lang = length $lang ? "[$lang] " : '';
            my $old_indent = $indent;
            $indent = 0;
            $add_text->("~code $lang\{\n$code}\n");
            $indent = $old_indent;
        }
        
        # NODE_HTML_INLINE
        elsif ($node_type == NODE_HTML_INLINE) {
            my $html = md_escape($node->get_literal);
            $add_text->("~html {$html}");
        }
        
        # NODE_HTML_BLOCK
        elsif ($node_type == NODE_HTML_BLOCK) {
            my $html = md_escape($node->get_literal);
            $add_text->("~html {\n$html}\n");
        }
        
        # NODE_BLOCK_QUOTE
        elsif ($node_type == NODE_BLOCK_QUOTE) {
            if ($ev_type == EVENT_ENTER) {
                $indent++;
                $add_text->("~quote {\n");
            }
            else {
                $indent--;
                $add_text->("\n}\n");
            }
        }
        
        # do nothing
        elsif ($node_type == NODE_DOCUMENT) {
            
        }
        
        else {
            my $node_type_s = $node->get_type_string;
            E "Unknown Markdown node '$node_type_s' ($es{$ev_type})";
        }
        
        # TODO:
        # NODE_THEMATIC_BREAK (horizontal rule)
    }
    
    # close remaining sections
    if ($header_level) {
        $indent--, $add_text->("\n}\n") for 1..$header_level;
    }
    
    # page metadata
    
    my @meta = (
        'page.title'        => $page_title,
        'page.author'       => 'Markdown',
        'page.generated'    => \1
    );
    
    my $meta_source = '';
    while (my ($k, $v) = splice @meta, 0, 2) {
        next if ref $v && !$$v;
        next if !length $v;
        $meta_source .= "\@$k";
        $meta_source .= ": $v" if !ref $v;
        $meta_source .= ";\n";
    }
    return <<END;
$meta_source

/* !!! DO NOT EDIT THIS PAGE !!!
   This page is auto-generated from $md_name. Any changes will be overwritten
   the next time the page is generated. Instead, edit $md_name directly.
*/

$source
END
}

# replace GFM tables with HTML
sub _md_table_replace {
    my ($wiki, $md_text) = @_;
    while ($md_text =~ s/$table_re/!!TABLE!!/) {
        __md_table_replace(\$md_text, $1, $2, $3);
    }
    while ($md_text =~ s/$np_table_re/!!TABLE!!/) {
        __md_table_replace(\$md_text, $1, $2, $3);
    }
    return $md_text;
}

sub __md_table_replace {
    my ($md_text_ref, $header, $align, $cell) = @_;
    
    # extract header cells
    $header =~ s/^ *| *\| *$//g;
    my @headers = split m/ *\| */, $header;
    
    # extract alignment
    $align =~ s/^ *|\| *$//g;
    my @aligns = split m/ *\| */, $align;
    
    # extract body cells
    $cell =~ s/(?: *\| *)?\n$//;
    my @cells = split m/\n/, $cell;

    # determine the alignment
    @aligns = map {
        my $align;
        if (/^ *-+: *$/) {
            $align = 'right';
        }
        elsif (/^ *:-+: *$/) {
            $align = 'center';
        }
        elsif (m/^ *:-+ *$/) {
            $align = 'left';
        }
        $align;
    } @aligns;

    # split up the body cells
    for my $i (0..$#cells) {
         my $cell = $cells[$i];
         $cell =~ s/^ *\| *| *\| *$//g;
         $cells[$i] = [ split m/ *\| */, $cell ]
    }
    
    # create table
    my $table       = Wikifier::Element->new(type => 'table', class => 'table');
    my $thead       = $table->create_child(type => 'thead');
    my $thead_tr    = $thead->create_child(type => 'tr');
    my $tbody       = $table->create_child(type => 'tbody');
    
    # add headers
    for my $col (0..$#headers) {
        my $header = $headers[$col];
        my $align  = $aligns[$col];
        $align = "text-align: $align;" if $align;
        $thead_tr->create_child(
            type        => 'th',
            attributes  => { style => $align },
            content     => md_to_html_np($header)
        );
    }
    
    # add body cells
    for my $row (0..$#cells) {
        my $row_ref = $cells[$row];
        my $tr = $tbody->create_child(type => 'tr');
        for my $col (0..$#$row_ref) {
            my $text  = $row_ref->[$col];
            my $align = $aligns[$col];
            $align = "text-align: $align;" if $align;
            $tr->create_child(
                type        => 'td',
                attributes  => { style => $align },
                content     => md_to_html_np($text)
            );
        }
    }
    
    # make the replacement
    my $html = $table->generate;
    $$md_text_ref =~ s/!!TABLE!!/\n$html\n/;
}

# convert markdown to html
sub md_to_html {
    my $md_text = shift;
    return CommonMark->markdown_to_html($md_text);
}

# strip outer <p></p>
sub md_to_html_np {
    my $html = md_to_html(@_);
    $html =~ s/^\s*<p>(.+)<\/p>\s*$/$1/;
    return $html;
}

# escape markdown-extracted text.
sub md_escape {
    my $text = shift;
    $text =~ s/([\{\}\\])/\\$1/g;
    return $text;
}

# escape markdown-extracted text for use in a block with text formatting
# enabled. if it's a block without text formatting, use md_escape().
sub md_escape_fmt {
    my $text = shift;
    $text =~ s/([;:\{\}\[\]\\])/\\$1/g;
    return $text;
}

1
