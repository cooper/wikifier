#
# Copyright (c) 2014, Mitchell Cooper
#
# The Wikifier is a simple wiki language parser. It merely converts wiki language to HTML.
# Wikifier::Wiki, on the other hand, provides a full wiki management mechanism. It
# features image sizing, page and image caching, and more.
#
# The Wikifier and Wikifier::Page can operate as only a parser without this class.
# This is useful if you wish to implement your own image resizing and caching methods
# or if you don't feel that these features are necessary.
#
package Wikifier::Wiki;

use warnings;
use strict;

use GD;                                 # image sizing
use HTTP::Date 'time2str';              # HTTP date formatting
use Digest::MD5 'md5_hex';              # etags
use Cwd 'abs_path';                     # resolving symlinks
use File::Basename 'basename';          # determining object names
use JSON qw(encode_json decode_json);   # caching and storing

use Wikifier;

# default options.
our %wiki_defaults = (
    'image.enable.restriction'  => 1,
    'enable.cache.image'        => 1,
    'enable.cache.page'         => 1,
    'enable.enable.retina'      => 1,
    'image.rounding'            => 'up',
    'image.size_method'         => 'server',
    'image.sizer'               => \&_wiki_default_sizer,
    'image.calc'                => \&_wiki_default_calc
);

# create a new wiki object.
sub new {
    my ($class, %opts) = @_;
    my $wiki = bless \%opts, $class;
    
    # if there were no provided options, assume we're reading from /etc/wikifier.conf.
    $wiki->read_config('/etc/wikifier.conf') if not scalar keys %opts;
    
    # if a config file is provided, use it.
    $wiki->read_config($opts{config_file}) if defined $opts{config_file};
    
    # create the Wiki's Wikifier instance.
    # using the same wikifier instance over and over makes parsing much faster.
    $wiki->{wikifier} ||= Wikifier->new();
    
    return $wiki;
}

# read options from a configuration page file.
sub read_config {
    my ($wiki, $file) = @_;
    my $conf = $wiki->{conf} = Wikifier::Page->new(
        file      => $file,
        vars_only => 1       # don't waste time parsing anything but variables
    );
    
    # error.
    if (!$conf->parse) {
        Wikifier::l("Failed to parse configuration");
        return;
    }
    
    return 1;
}

# returns a wiki option.
sub opt {
    my ($wiki, $opt) = @_;
    return $wiki->{$opt} if exists $wiki->{$opt};
    my $v = $wiki->{conf}->get($opt);
    return defined $v ? $v :
        $wiki_defaults{$opt} //
        $Wikifier::Page::wiki_defaults{$opt};
}

#############   This is Wikifier's built in URI handler. If you wish to implement your own
# display() #   URI handler, simply have it call the other display_*() methods directly.
#############   Returns information for displaying a wiki page or resource.
#
# Pages
# -----
#
#  Takes a page name such as:
#    Some Page
#    some_page
#
# Images
# ------
#
#  Takes an image in the form of:
#    image/[imagename].png
#    image/[width]x[height]-[imagename].png
#
#  For example:
#    image/flower.png
#    image/400x200-flower.png
#
# Returns
# -------
#
# Returns a hash reference of results for display.
#   type: either 'page', 'image', or 'not found'
#   
#   if the type is 'page':
#       cached:     true if the content was fetched from cache.
#       generated:  true if the content was just generated.
#       cache_gen:  true if the content was generated and has been cached.
#       page:       the Wikifier::Page object representing the page. (if generated)
#
#   if the type is 'image':
#       image_type: either 'jpeg' or 'png'
#       image_data: the image binary data (synonym to 'content')
#       cached:     true if the image was fetched from cache.
#       generated:  true if the image was just generated.
#       cache_gen:  true if the image was generated and has been cached.
#
#   for anything except errors, the following will be set:
#       file:       the filename of the resource (not path) ex 'hello.png' or 'some.page'
#       path:       the full path of the resource ex '/srv/www/example.com/hello.png'
#       mime:       the MIME type, such as 'text/html' or 'image/png'
#       modified:   the last modified date of the resource in HTTP date format
#       length:     the length of the resource in octets
#       etag:       an HTTP etag for the resource in the form of an md5 string
#       content:    the page content or binary data to be sent to the client
#
#   if the type is 'not found'
#       error: a string error.
#
sub display {
    my ($wiki, $page_name) = (shift, shift);
    
    # it's an image.
    if ($page_name =~ m|^image/(.+)$|) {
        my ($image_name, $width, $height, $file_name) = $1;
        
        # height and width were given, so it's a resized image.
        if ($image_name =~ m/^(\d+)x(\d+)-(.+)$/) {
            ($width, $height, $file_name) = ($1, $2, $3);
        }
        
        # only file name was given, so the full sized image is desired.
        else {
            ($width, $height, $file_name) = (0, 0, $image_name);
        }
    
        return $wiki->display_image($file_name, $width, $height);
    }
    
    # it's a wiki page.
    else {
        return $wiki->display_page($page_name);
    }
    
    # not sure.
    return {
        type  => 'not found',
        error => 'Unsure how to handle this request'
    };
    
}

#############
### PAGES ###
#############

# Displays a page.
sub display_page {
    my ($wiki, $page_name) = @_; my $result = {};
    
    # replace spaces with _ and lowercase.
    $page_name =~ s/\s/_/g;
    $page_name = lc $page_name;
    
    # append .page if it isn't already there.
    if ($page_name !~ m/\.page$/) {
        $page_name .= q(.page);
    }
    
    # determine the page file name.
    my $file       = abs_path($wiki->opt('dir.page').q(/).$page_name);
       $page_name  = basename($file);
    my $cache_file = $wiki->opt('dir.cache').q(/).$page_name.q(.cache);
    
    # file does not exist.
    if (!-f $file) {
        $result->{error} = "Page '$page_name' does not exist.";
        $result->{type}  = 'not found';
        return $result;
    }
    
    # set path, file, and meme type.
    $result->{file} = $page_name;
    $result->{path} = $file;
    $result->{mime} = 'text/html';
    
    # caching is enabled, so let's check for a cached copy.
    
    if ($wiki->opt('enable.cache.page') && -f $cache_file) {
        my ($page_modify, $cache_modify) = ((stat $file)[9], (stat $cache_file)[9]);
    
        # the page's file is more recent than the cache file.
        if ($page_modify > $cache_modify) {
        
            # discard the outdated cached copy.
            unlink $cache_file;
        
        }
        
        # the cached file is newer, so use it.
        else {
            my $time = time2str($cache_modify);
            $result->{type}     = 'page';
            $result->{content}  = "<!-- cached page dated $time -->\n\n";
            
            # fetch the prefixing data.
            my $cache_data = file_contents($cache_file);
            my @data = split /\n\n/, $cache_data, 2;
            
            # decode.
            my $jdata = eval { decode_json(shift @data) } || {};
            if (ref $jdata eq 'HASH') {
                $result->{$_} = $jdata->{$_} foreach keys %$jdata;
            }
            
            # set HTTP data.
            
            $result->{content} .= shift @data;
            $result->{cached}   = 1;
            $result->{modified} = $time;
            $result->{length}   = length $result->{content};
            
            return $result;
        }
        
    }
    
    # cache was not used. generate a new copy.
    my $page = $result->{page} = Wikifier::Page->new(
        name     => $page_name,
        file     => $file,
        wiki     => $wiki,
        wikifier => $wiki->{wikifier}
    );
    
    # parse the page.
    $page->parse();
    $wiki->check_categories($page);
    
    # generate the HTML and headers.
    $result->{type}       = 'page';
    $result->{content}    = $page->html;
    $result->{length}     = length $result->{content};
    $result->{generated}  = 1;
    $result->{modified}   = time2str(time);
    $result->{categories} = $page->{categories} if $page->{categories};
    
    # caching is enabled, so let's save this for later.
    if ($wiki->opt('enable.cache.page')) {
    
        open my $fh, '>', $cache_file;
        
        # save prefixing data.
        print {$fh} JSON->new->pretty(1)->encode({
            %{ $page->get('page') || {} },
            categories => $result->{categories} || []
        }), "\n";
        
        # save the content.
        print {$fh} $result->{content};
        
        close $fh;
        
        # overwrite modified date to actual.
        $result->{modified}  = time2str((stat $cache_file)[9]);
        $result->{cache_gen} = 1;
        
    }
    
    return $result;
}

##############
### IMAGES ###
##############

# Displays an image of the supplied dimensions.
sub display_image {
    my ($wiki, $image_name, $width, $height, $dont_open) = @_;
    my ($result, $scaled_w, $scaled_h) = ({}, $width, $height);
    
    # split image parts.
    $image_name =~ m/^(.+)\.(.+?)$/;
    my ($image_wo_ext, $image_ext) = ($1, $2);
    
    # early retina check.
    my ($name_width, $name_height) = ($width, $height);
    my $retina_request = $image_wo_ext =~ m/^(.+)\@2x$/;
    
    # if this is a retina request, calculate 
    if ($retina_request) {
        $image_wo_ext = $1;
        $image_name   = $1.q(.).$image_ext;
        $width       *= 2;
        $height      *= 2;
    }
    
    # check if the file exists.
    my $file = abs_path($wiki->opt('dir.image').q(/).$image_name);
    if (!-f $file) {
        $result->{type}  = 'not found';
        $result->{error} = "Image '$image_name' does not exist.";
        return $result;
    }
    
    # stat for full-size image.
    my @stat = stat $file;
    
    # image name and full path.
    $result->{type} = 'image';
    $result->{file} = $image_name;
    $result->{path} = $file;
    $result->{fullsize_path} = $file;
    
    # determine image short name, extension, and mime type.
    $image_name      =~ m/(.+)\.(.+)/;
    my ($name, $ext) = ($1, $2);
    my $mime         = $ext eq 'png' ? 'image/png' : 'image/jpeg';

    # image type and mime type.    
    $result->{image_type}   = $ext eq 'jpg' || $ext eq 'jpeg' ? 'jpeg' : 'png';
    $result->{mime}         = $mime;
    
##################################   
### THIS IS A FULL-SIZED IMAGE ###
##########################################################################################
    
    # if no width or height are specified,
    # display the full-sized version of the image.
    if (!$width || !$height) {
        $result->{content}      = file_contents($file, 1) unless $dont_open;
        $result->{modified}     = time2str($stat[9]);
        $result->{length}       = $stat[7];
        $result->{etag}         = q(").md5_hex($image_name.$result->{modified}).q(");
        return $result;
    }
    
##############################   
### THIS IS A SCALED IMAGE ###
##########################################################################################

    #############################
    ### RETINA SCALE SUPPORT ####
    #############################
    
    # note: retina image name is handled above in "early retina check."
    
    # this is not a retina request, but retina is enabled, and so is pregeneration.
    # therefore, we will call ->display_image() in order to pregenerate a retina version.
    if ($wiki->opt('image.enable.retina') && !$retina_request &&
           $wiki->opt('image.enable.pregeneration')) {
        my $retina_file = $image_wo_ext.q(@2x.).$image_ext;
        $wiki->display_image($retina_file, $width, $height, 1);
    }
    
    # determine the full file name of the image.
    my $full_name  = $retina_request
                     ? $name_width.q(x).$name_height.q(-).$image_wo_ext.q(@2x.).$image_ext
                     : $name_width.q(x).$name_height.q(-).$image_name;
    my $cache_file = $wiki->opt('dir.cache').q(/).$full_name;
    
    #############################
    ### FINDING CACHED IMAGE ####
    #############################
    
    # if caching is enabled, check if this exists in cache.
    if ($wiki->opt('enable.cache.image') && -f $cache_file) {
        my ($image_modify, $cache_modify) = ((stat $file)[9], (stat $cache_file)[9]);
        
        # the image's file is more recent than the cache file.
        if ($image_modify > $cache_modify) {
        
            # discard the outdated cached copy.
            unlink $cache_file;
        
        }
        
        # the cached file is newer, so use it.
        else {
            
            # set HTTP data.
            $result->{path}         = $cache_file;
            $result->{cache_path}   = $cache_file;
            $result->{cached}       = 1;
            $result->{content}      = file_contents($cache_file, 1) unless $dont_open;
            $result->{modified}     = time2str($cache_modify);
            $result->{etag}         = q(").md5_hex($image_name.$result->{modified}).q(");
            $result->{length}       = -s $cache_file;
            
            return $result;
        }
        
    }
    
    # if image generation is disabled, we must supply the full-sized image data.
    if (!$wiki->opt('enable.cache.image')) {
        return $wiki->display_image($result, $image_name, 0, 0);
    }
    
    ##############################
    ### GENERATION, NOT CACHED ###
    ##############################
    
    # if we are restricting to only sizes used in the wiki, check.
    if ($wiki->opt('image.enable.restriction')) {
        if (!$wiki->{allowed_dimensions}{$image_name}{ $scaled_w.q(x).$scaled_h }) {
            $result->{type}  = 'not found';
            $result->{error} = "Image '$image_name' does not exist in these dimensions.";
            return $result;
        }
    }
    
    GD::Image->trueColor(1);
    my $full_image = GD::Image->new($file);

    # create resized image.
    my $image = GD::Image->new($width, $height);
    $image->saveAlpha(1);
    $image->alphaBlending(0);
    $image->copyResampled($full_image,
        0, 0,
        0, 0,
        $width, $height,
        $full_image->getBounds
    );
    
    # create JPEG or PNG data.
    my $use = $wiki->opt('image.type') || $result->{image_type};
    if ($use eq 'jpeg') {
        my $compression = $wiki->opt('image.quality') || 100;
        $result->{content} = $image->jpeg($compression);
    }
    else {
        $image->saveAlpha(1);
        $image->alphaBlending(0);
        $result->{content} = $image->png();
    }

    $result->{generated}    = 1;
    $result->{modified}     = time2str(time);
    $result->{length}       = length $result->{content};
    $result->{etag}         = q(").md5_hex($image_name.$result->{modified}).q(");
    
    # caching is enabled, so let's save this for later.
    if ($wiki->opt('enable.cache.image')) {
    
        open my $fh, '>', $cache_file;
        print {$fh} $result->{content};
        close $fh;
        
        # overwrite modified date to actual.
        $result->{path}       = $cache_file;
        $result->{cache_path} = $cache_file;
        $result->{modified}   = time2str((stat $cache_file)[9]);
        $result->{cache_gen}  = 1;
        $result->{etag}       = q(").md5_hex($image_name.$result->{modified}).q(");
        
    }
    
    delete $result->{content} if $dont_open;
    return $result;
}

##################
### CATEGORIES ###
##################

# displays a pages from a category in a blog-like form.
sub display_category_posts {
    my ($wiki, $category, $page_n) = @_; my $result = {};
    my ($pages, $title) = $wiki->cat_get_pages($category);
    if (!$pages) {
        $result->{error} = "Category '$category' does not exist.";
        $result->{type}  = 'not found';
        return $result;
    }
    
    $result->{type}     = 'catposts';
    $result->{category} = $category;
    $result->{title}    = $title if defined $title;
    
    my (%times, %reses);
    foreach my $page_name (keys %$pages) {
        my $page_data = $pages->{$page_name};
        my $res  = $wiki->display_page($page_name);
        my $time = $res->{page} ? $res->{page}->get('page.created')
                   : $res->{created} || 0;
        
        $times{$page_name} = $time || 0;
        $reses{$page_name} = $res;
    }
    
    # order with newest first.
    my @pages_in_order = sort { $times{$b} cmp $times{$a} } keys %times;
    @pages_in_order    = map  { $reses{$_} } @pages_in_order;
    #$result->{pages} = \@pages_in_order;
    
    # order into PAGES of pages. wow.
    my $limit = $wiki->opt('enable.category_post_limit') || 'inf';
    my $n = 1;
    while (@pages_in_order) {
        $result->{pages}{$n} ||= [];
        for (1..$limit) {
            last unless @pages_in_order; # no more
            push @{ $result->{pages}{$n} }, shift @pages_in_order;
        }
        $n++;
    }
    
    return $result;
}

# deal with categories after parsing a page.
sub check_categories {
    my ($wiki, $page) = @_;

    # actual categories.
    my $cats = $page->get('category');
    if ($cats && ref $cats eq 'HASH') {
        $page->{categories} = [keys %$cats];
        $wiki->cat_add_page($page, $_) foreach keys %$cats;
    }
    
    # image categories.
    return unless $wiki->opt('image.enable.tracking');
    $wiki->cat_add_page($page, "image-$_") foreach keys %{ $page->{images} || {} };

}

# add a page to a category if it is not in it already.
sub cat_add_page {
    my ($wiki, $page, $category) = @_;
    my ($time, $fh) = time;
    my $cat_file = $wiki->opt('dir.category').q(/).$category.q(.cat);
    
    # fetch page infos.
    my $p_vars = $page->get('page');
    my $page_data = { asof => $time };
    if (ref $p_vars eq 'HASH') {
        foreach my $var (keys %$p_vars) {
            next if $var eq 'asof';
            $page_data->{$var} = $p_vars->{$var};
        }
    }
    
    # this is an image category, so include the dimensions.
    if ($category =~ m/^image-(.+)$/) {
        $page_data->{dimensions} = $page->{images}{$1};
    }
    
    # first, check if the category exists yet.
    if (-f $cat_file) {
        my $cat = eval { decode_json(file_contents($cat_file)) };
        
        # JSON error or the value is not a hash.
        if (!$cat || ref $cat ne 'HASH') {
            Wikifier::l("Error parsing JSON category '$cat_file': $@");
            close $fh;
            return;
        }
        
        # update information for this page,
        # or add it if it is not there already.
        $cat->{pages}{ $page->{name} } = $page_data;
        
        # open the file or log error.
        if (!open $fh, '>', $cat_file) {
            Wikifier::l("Cannot open '$cat_file': $!");
            return;
        }
        
        # print the resulting JSON.
        print {$fh} JSON->new->pretty(1)->encode($cat);
        close $fh;
        
        return 1;
    }
    
    # open file or error.
    if (!open $fh, '>', $cat_file) {
        Wikifier::l("Cannot open '$cat_file': $!");
        return;
    }
    
    # the category does not yet exist.
    print {$fh} JSON->new->pretty(1)->encode({
        category   => $category,
        created    => $time,
        pages      => { $page->{name} => $page_data }
    });
    
    close $fh;
    return 1;
}

# returns the names of the pages in the given category.
# if the category does not exist, an undefined value is returned.
sub cat_get_pages {
    my ($wiki, $category) = @_;
    # this should read a file for pages of a category.
    # it should then check if the 'asof' time is older than the modification date of the
    # page file in question. if it is, it should check the page again. if it still in
    # the category, the time in the cat file should be updated to the current time. if it
    # is no longer in the category, it should be removed from the cat file.
    
    # this category does not exist.
    my $cat_file = $wiki->opt('dir.category').q(/).$category.q(.cat);
    return unless -f $cat_file;
    
    # it exists; let's see what's inside.
    my $cat = eval { decode_json(file_contents($cat_file)) };
    
    # JSON error or the value is not a hash.
    if (!$cat || ref $cat ne 'HASH') {
        Wikifier::l("Error parsing JSON category '$cat_file': $@");
        return;
    }

    # check each page's modification date.
    my ($time, $changed, %final_pages) = time;
    PAGE: foreach my $page_name (%{ $cat->{pages} || {} }) {
        my $page_data = my $p = $cat->{pages}{$page_name};
        
        # determine the page file name.
        my $page_path = abs_path($wiki->opt('dir.page').q(/).$page_name);
        
        # page no longer exists.
        if (!-f $page_path) {
            $changed = 1;
            next PAGE;
        }
        
        # check if the modification date is more recent than as of date.
        my $mod_date = (stat $page_path)[9];
        if ($mod_date > $p->{asof}) {
            $changed = 1;
            
            # the page has since been modified.
            # we will create a dummy Wikifier::Page that will stop after reading variables.
            my $page = Wikifier::Page->new(
                name      => $page_name,
                file      => $page_path,
                wikifier  => $wiki->{wikifier},
                vars_only => 1 # don't waste time parsing anything but variables
            );
            $page->parse;
            
            # update data.
            my $p_vars = $page->get('page');
            $page_data = { asof => $time };
            if (ref $p_vars eq 'HASH') {
                foreach my $var (keys %$p_vars) {
                    next if $var eq 'asof';
                    $page_data->{$var} = $p_vars->{$var};
                }
            }
            
            # page is no longer member of category.
            if ($category =~ m/^image-(.+)/) {
                next PAGE unless defined $page->{images}{$1};
            }
            else {
                next PAGE unless $page->get("category.$category");
            }
            
        }
        
        # nothing has changed. this one made it.
        $final_pages{$page_name} = $page_data;
        
    }
    
    # it looks like something has changed. we need to update the cat file.
    if ($changed) {
    
        # is this category now empty?
        if (!scalar keys %final_pages) {
            unlink $cat_file;
            return;
        }
    
        # no, there are still page(s) in it.
        # update the file.
        
        $cat->{updated} = $time;
        $cat->{pages}   = \%final_pages;
        
        # unable to open.
        my $fh;
        if (!open $fh, '>', $cat_file) {
            Wikifier::l("Cannot open '$cat_file': $!");
            return;
        }
        
        print {$fh} JSON->new->pretty(1)->encode($cat);
        close $fh;
        
    }
    
    return wantarray ? (\%final_pages, $cat->{title}) : \%final_pages;
}

##################
### WIKI FILES ###
##################

# an array of file names in page directory.
sub all_pages {
    return files_in_dir(shift->opt('dir.page'), 'page');
}

# an array of file names in category directory.
sub all_categories {
    return files_in_dir(shift->opt('dir.category'), 'cat');
}

#####################
### MISCELLANEOUS ###
#####################

# files in directory.
# resolves symlinks only counts each file once.
sub files_in_dir {
    my ($dir, $ext) = @_;
    opendir my $dh, $dir or Wikifier::l("Cannot open dir '$dir': $!") and return;
    my %files;
    while (my $file = readdir $dh) {
        
        # skip hidden files.
        next if substr($file, 0, 1) eq '.';
        
        # skip files without desired extension.
        next if $ext && $file !~ m/.+\.$ext$/;
        
        # resolve symlinks.
        my $file = abs_path($dir.q(/).$file);
        next if !$file; # couldn't resolve symlink.
        $file = basename($file);
        
        # already got this one.
        next if $files{$file};
        
        $files{$file} = 1;
    }
    closedir $dh;
    return keys %files;
}

# returns entire contents of a file.
sub file_contents {
    my ($file, $binary) = @_;
    local $/ = undef;
    open my $fh, '<', $file or Wikifier::l("Cannot open file '$file': $!") and return;
    binmode $fh if $binary;
    my $content = <$fh>;
    close $fh;
    return $content;
}

# default image calculator for a wiki.
sub _wiki_default_calc {
    my %img  = @_;
    my $page = $img{page};
    my $wiki = $page->{wiki};
    my $file = $page->wiki_opt('dir.image').q(/).$img{file};
    
    # find the image size using GD.
    my $full_image      = GD::Image->new($file) or return (0, 0);
    my ($big_w, $big_h) = $full_image->getBounds();
    undef $full_image;
    
    # call the default handler with these dimensions.
    my ($w, $h) = Wikifier::Page::_default_calculator(
        %img,
        big_width  => $big_w,
        big_height => $big_h
    );
    
    # store these as accepted dimensions.
    $wiki->{allowed_dimensions}{ $img{file} }{ $w.q(x).$h } = 1;
    
    # pregenerate if necessary.
    # this allows the direct use of the cache directory as served from
    # the web server, reducing the wikifier server's load when requesting
    # cached pages and their images.
    if ($page->wiki_opt('image.enable.pregeneration')) {
        my $res = $wiki->display_image($img{file}, $w, $h, 1);
        Wikifier::l("Pregenerated image '$$res{file}' at ${w}x${h}") if $res->{cache_gen};
        
        # we must symlink to images in cache directory.
        unlink  $page->wiki_opt('dir.cache').q(/).$img{file};
        symlink $page->wiki_opt('dir.image').q(/).$img{file},
                $page->wiki_opt('dir.cache').q(/).$img{file};
        
    }
    
    return ($w, $h);

}

# default image sizer for a wiki.
sub _wiki_default_sizer {
    my %img = @_;
    my $page = $img{page};
    my $wiki = $page->{wiki};
    
    # full-sized image.
    if (!$img{width} || !$img{height} ||
        $img{width} eq 'auto' || $img{height} eq 'auto') {
        
        return $wiki->opt('root.image').q(/).$img{file};
    }
    
    # scaled image.
    return $wiki->opt('root.image').q(/).$img{width}.q(x).$img{height}.q(-).$img{file};
    
}


1
