#
# Copyright (c) 2014, Mitchell Cooper
#
# Version control methods for WiWiki.
#
package Wikifier::Wiki;

use warnings;
use strict;
use Git::Wrapper;

sub write_page {
    my ($wiki, $page, $reason) = @_;

    # write the file
    open my $fh, '>', $page->path or return;
    print {$fh} $page->{content};
    close $fh;
    
    # update the page
    $wiki->display_page($page);
    
    # commit the change
    $wiki->rev_commit(
        message => defined $reason ? "Updated $$page{name}: $reason" : "Created $$page{name}",
        add     => [ $page->path ]
    );
    
    return 1;
}

sub delete_page {
    my ($wiki, $page) = @_;
    
    # delete the file as well as the cache
    # consider: should we just let git rm unlink them?
    unlink $page->path or return;
    unlink $page->cache_path; # may or may not exist
    
    # commit the change
    $wiki->rev_commit(
        message => "Deleted $$page{name}",
        rm      => [ $page->path, $page->cache_path ]
    );
    
    return 1;
}

sub move_page {
    my ($wiki, $page, $new_name) = @_;
    $new_name = Wikifier::Page::_page_filename($new_name);
    my ($old_name, $old_path) = ($page->name, $page->path);
    $page->{name} = $new_name;

    # consider: what if the destination page exists?
    
    # delete the old cache file
    unlink $page->cache_path; # may or may not exist
    
    # move the file as well as the cache
    # consider: should we just let git mv move it?
    rename $old_path, $page->path or do {
        $page->{name} = $old_name;
        return;
    };
    
    # update the page
    $wiki->display_page($page);
    
    # commit the change
    $wiki->rev_commit(
        message => "Moved $old_name -> $new_name",
        mv      => { $old_path => $page->path }
    );
    
    return 1;
}

####################################
### LOW-LEVEL REVISION FUNCTIONS ###
####################################

sub capture_logs(&$) {
    my ($code, $command) = @_;
    eval { $code->() };
    if ($@ && ref $@ eq 'Git::Wrapper::Exception') {
        my $message = $command.' exited with code '.$@->status.'. ';
        $message .= $@->error.$/.$@->output;
        Wikifier::l($message);
    }
    elsif ($@) {
        Wikifier::l('Unspecified git error');
    }
    return 1;
}

# commit a revision
our $git;
sub rev_commit (@) {
    my $wiki = shift;
    if (!$git) {
        my $dir = $wiki->opt('dir.wiki');
        if (!length $dir) {
            Wikifier::l('Cannot commit; @dir.wiki not set');
            return;
        }
        $git = Git::Wrapper->new($dir);
    }
    eval { &_rev_commit };
}

sub _rev_commit {
    my %opts = @_;
    my ($rm, $add, $mv) = @opts{'rm', 'add', 'mv'};
    if ($rm && ref $rm eq 'ARRAY') {
        capture_logs { $git->rm(@$rm) } 'git rm';
    }
    if ($add && ref $add eq 'ARRAY') {
        capture_logs { $git->add(@$add) } 'git add';
    }
    if ($mv && ref $mv eq 'HASH') {
        foreach (keys %$mv) {
            capture_logs { $git->mv($_, $mv->{$_}) } 'git mv';
        }
    }
    Wikifier::l("git commit: $opts{message}");
    capture_logs { $git->commit({ message => $opts{message} // 'Unspecified' }) } 'git commit';
}

# convert objects to file paths.
sub _filify {
    my @objects_and_files = @_;
    my @paths;
    foreach my $thing (@objects_and_files) {
        my $path = $thing;
        $path = _path($thing) if blessed $thing;
        push @paths, $path;
    }
    return @paths;
}

sub _path {
    my $thing = shift;
    return $thing->path;
}

1
