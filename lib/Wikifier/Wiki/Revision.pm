# Copyright (c) 2017, Mitchell Cooper
#
# Version control methods for WiWiki.
#
package Wikifier::Wiki;

use warnings;
use strict;
use Git::Wrapper;
use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(page_name L E back);
use File::Spec;

sub write_page {
    my ($wiki, $page, $reason) = @_;
    Lindent "WRITE($$page{name})";

    # determine reason
    $reason = length $reason            ?
        "Updated $$page{name}: $reason" :
        "Updated $$page{name}";

    # open the file
    my $fh;
    if (!open $fh, '>', $page->path) {
        E 'Failed to open page file for writing';
        back;
        return;
    }
    
    # write
    binmode $fh, ':utf8';
    print {$fh} $page->{content} if !ref $page->{content};
    close $fh;

    # update the page
    my $display_method = $page->{is_model} ? 'display_model' : 'display_page';
    $wiki->$display_method($page, draft_ok => 1);

    # commit the change
    my @res = $wiki->rev_commit(
        message => $reason,
        add     => [ $page->path ]
    );
    
    back;
    return @res;
}

sub delete_page {
    my ($wiki, $page) = @_;
    Lindent "DELETE($$page{name})";

    # commit the change
    $wiki->rev_commit(
        message => "Deleted $$page{name}",
        rm      => [ $page->path, $page->cache_path ]
    );

    unlink $page->cache_path;
    unlink $page->path;
    
    back;
    return 1;
}

# rename a page
# returns nothing on success, error string on failure
sub move_page {
    my ($wiki, $page, $new_name, $allow_overwrite) = @_;
    Lindent "MOVE($$page{name} -> $new_name)";
    $new_name = page_name($new_name);
    my ($old_name, $old_path) = ($page->name, $page->path);
    
    # this should never happen
    if ($page->name ne $page->rel_name) {
        back;
        return 'Page appears to be a symbolic link';
    }
    
    # change the name, but keep the old name until after we ->display_page().
    # this is used to update categories the page belongs to.
    $page->{name} = $new_name;
    $page->{old_name} = $old_name;
    delete $page->{cached_props};

    # trying to overwrite
    if (!$allow_overwrite && -e $page->path) {
        back;
        return 'Destination filename already exists';
    }
    
    # delete the old cache file
    unlink $page->cache_path; # may or may not exist

    # commit the change
    $wiki->rev_commit(
        message => "Moved $old_name -> $new_name",
        mv      => { $old_path => $page->path }
    );

    # update the page
    my $display_method = $page->{is_model} ? 'display_model' : 'display_page';
    $wiki->$display_method($page);
    delete $page->{old_name};

    back;
    return;
}

*write_model    = \&write_page;
*delete_model   = \&delete_page;
*move_model     = \&move_page;

####################################
### LOW-LEVEL REVISION FUNCTIONS ###
####################################

my @op_errors;
sub _rev_op_commit (&$) {
    my ($code, $command) = @_;
    L $command;
    
    # call in list context
    my @ret = eval { $code->() };
        
    # git exception occurred
    if ($@ && ref $@ eq 'Git::Wrapper::Exception') {
        my $message = "`$command` exited with status ".$@->status.'. ';
        $message .= $@->error.$/.$@->output;
        E $message;
        push @op_errors, $message;
        return;
    }
    
    # other error occurred
    elsif ($@) {
        my $message = 'Unspecified git error';
        E $message;
        push @op_errors, $message;
        return;
    }
    
    return @ret;
}

# return the results of the operations
# clear the list of operation results
#
# if all operations were successful,
# this returns an empty list
#
sub _rev_op_complete () {
    my @ops = @op_errors;
    @op_errors = ();
    return wantarray ? @ops : $ops[0];
}

# get info about the latest revision (commit)
# returns a hash reference containing the following:
#
# id
# author
# date
# message
#
sub rev_latest {
    my $wiki = shift;
    my $git  = $wiki->_prepare_git() or return;
    my @logs = _rev_op_commit { $git->log } 'git log';
    my $err  = _rev_op_complete;
    return { error => $err } if $err;
    my $last = shift @logs or return;
    return {
        id            => $last->id,
        author        => $last->author,
        date          => $last->date,
        message       => $last->message
    };
}

# find all revisions involving the specified page.
# returns a list of hash reference containing the same keys as rev_latest
sub revs_matching_page {
    my ($wiki, $page_or_name) = @_;
    return $wiki->_revs_matching_file($page_or_name->path) if blessed $page_or_name;
    return $wiki->_revs_matching_file($wiki->path_for_page($page_or_name));
}

# returns the diff for a page between the specified commits.
# if $to is not provided, the current version is used.
sub diff_for_page {
    my ($wiki, $page_or_name, $from, $to) = @_;
    my $git = $wiki->_prepare_git or return;
    $to ||= 'HEAD';

    # determine page path
    my $page_path = blessed $page_or_name ? $page_or_name->path :
        $wiki->path_for_page($page_or_name);
    return if !defined $page_path;
    
    # run git diff
    my @lines = _rev_op_commit {
        $git->diff("$from..$to", $page_path)
    } "git diff $from..$to $page_path";
    
    # check for error
    my $err = _rev_op_complete;
    return if $err; # TODO: return the error somehow
    
    return join "\n", @lines;
}

# find all revisions involving the specified file by absolute path.
# returns a list of hash reference containing the same keys as rev_latest
sub _revs_matching_file {
    my ($wiki, $path) = @_;
    return if !defined $path;
    my @matches;
    
    # look for matching modifications
    my $git  = $wiki->_prepare_git or return;
    my @logs = _rev_op_commit { $git->log('--', $path) } 'git log';
    
    # check for error
    my $err = _rev_op_complete;
    return if $err; # TODO: return the error somehow
    
    foreach my $log (@logs) {
        push @matches, {
            id            => $log->id,
            author        => $log->author,
            date          => $log->date,
            message       => $log->message
        };
    }
    return @matches;
}

# create a git object for this wiki if there isn't one
sub _prepare_git {
    my $wiki = shift;
    my $git = $wiki->{git};
    if (!$git) {
        
        # check for dir.wiki
        my $dir = $wiki->opt('dir.wiki');
        if (!length $dir) {
            L 'Revision tracking disabled; @dir.wiki not set';
            return;
        }
        
        # create `git` wrapper
        $git = $wiki->{git} = Git::Wrapper->new($dir);
        if (!$wiki->{git}->has_git_in_path) {
            L "Revision tracking disabled; can't find `git` in PATH";
            return;
        }
        
        # check if the repository exists. if not, initialize it
        if (!-d "$dir/.git") {
            my @create = (
                'git init' => sub {
                    _rev_op_commit { $git->init() } 'git init';
                    return _rev_op_complete;
                },
                'create .gitignore' => sub {
                    my $cache_dir = $wiki->opt('dir.cache');
                    $cache_dir = File::Spec->abs2rel($cache_dir, $dir);
                    open my $fh, '>', "$dir/.gitignore" or return $!;
                    print $fh <<END;
.DS_Store
*~
*.old
*.save
*.sock
private/*
$cache_dir/*
END
                    close $fh;
                    return;
                },
                'initial commit' => sub {
                    return $wiki->rev_commit(
                        message => 'initial commit',
                        add     => [ $dir ]
                    );
                }
            );
            while (my ($comment, $code) = splice @create, 0, 2) {
                my @errors = $code->();
                next unless @errors;
                E @errors;
                return;
            }
        }
    }
    return $wiki->{git};
}

# commit a revision
# returns a list of errors or an empty list on success
sub rev_commit (@) {
    my ($wiki, %opts) = (shift, @_);
    my $git = $wiki->_prepare_git or return;

    # add the author maybe
    my $user = $wiki->{user};
    if ($user && length $user->{name} && length $user->{email}) {
        $opts{author} = "$$user{name} <$$user{email}>";
    }

    return eval { _rev_commit($git, %opts) };
}

sub _rev_commit {
    my ($git, %opts) = @_;
    my ($rm, $add, $mv) = @opts{'rm', 'add', 'mv'};

    # rm operation
    if ($rm && ref $rm eq 'ARRAY' && @$rm) {
        _rev_op_commit { $git->rm($_) } "git rm $_" foreach @$rm;
    }

    # add operation
    if ($add && ref $add eq 'ARRAY' && @$add) {
        _rev_op_commit { $git->add($_) } "git add $_" foreach @$add;
    }

    # mv operation
    if ($mv && ref $mv eq 'HASH' && keys %$mv) {
        foreach (keys %$mv) {
            _rev_op_commit { $git->mv($_, $mv->{$_}) } 'git mv';
        }
    }

    my @more;

    # add commit author maybe
    if (length $opts{author}) {
        L "Using author $opts{author}";
        push @more, author => $opts{author};
    }

    # commit operations
    _rev_op_commit {

        $git->commit({
            message => $opts{message} // 'Unspecified',
            @more
        })

    } 'git commit';

    # return errors
    return _rev_op_complete;
}

1
