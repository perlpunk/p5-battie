package WWW::Battie::Modules::Gallery;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module::Model';
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(public_url private_dir model scale));
my %functions = (
    functions => {
        gallery => {
            _default => 'list',
            start => 1,
            view => 1,
            list => 1,
            cat => 1,

            create => 1,
            edit => 1,
            cat_edit => 0,
            upload_image => 1,
            edit_image => 1,
            edit_image_title => 1,
            view_image => 1,

            init =>{
                on_run => 1,
            },
        },
    },
);
sub functions { %functions }
my $rows = 12;

sub default_actions {
    my ($class, $battie) = @_;
    return {
        guest => [qw/ start view list view_image init /],
        gallery_editor => [qw/ create edit upload_image edit_image edit_image_title /],
    };
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['gallery', 'start'],
            text => $battie->translate('gallery'),
        };
    };
}

use Image::Resize;
use File::Copy ();

sub from_ini {
    my ($class, $battie, $args) = @_;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$args], ['args']);
    my $public_url = $args->{PUBLIC_IMAGE_URL};
    #my $public_dir = $battie->get_paths->{docroot} . $public_url;
    #die "Directory '$public_dir' is not writeable" unless -w $public_dir;
    my $private_dir = $args->{PRIVATE_IMAGE_DIR};
    #die "Directory '$private_dir' is not writeable" unless -w $private_dir;
    my $scale = $args->{SCALE} || 100;
    my $self = $class->new({
            public_url => $public_url,
            private_dir => $private_dir,
            model => $args->{MODEL},
            scale => $scale,
        });
}

sub model {
    gallery => 'WWW::Battie::Model::DBIC::Gallery'
}

sub gallery__init {
    my ($self, $battie) = @_;
    if ($battie->request->get_page eq 'gallery') {
        my $data = $battie->get_data;
        # set additional css link
        $data->{userprefs}->{local_css}->{gallery} = 'gallery';
    }
}

sub gallery__start {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $args = $request->get_args;
}

sub gallery__create {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    if ($submit->{create} and not $battie->valid_token) {
        delete $submit->{create};
        $data->{gallery}->{error}->{token} = 1;
    }
    my $new_cat = $request->param('gallery.cat') || 0;
    $new_cat =~ tr/0-9//cd;
    if ($submit->{create} and ! $new_cat) {
        delete $submit->{create};
        $data->{gallery}->{error}->{no_cat_selected} = 1;
    }
    my $schema = $self->schema->{gallery};
    my $cats = $schema->set('Category', 'fetch_tree');
    my $title = $request->param('gallery.title');
    $data->{gallery}->{title} = $title;

    $data->{gallery}->{categories} = [0, map {
        [$_->id, ('- ' x ($_->level * 2)) . ' ' . $_->title] } @$cats
    ];
    if ($submit->{create}) {
        not $request->is_post and $self->exception("Argument", "Sorry");
        $self->exception("Argument", "'$title' is not a valid title")
            unless WWW::Battie::Model::DBIC::Gallery->valid_title($title);
        $schema->txn_begin;
        eval {
            my $info_rs = $schema->resultset('Info');
            my $exists = $info_rs->find({ title => $title }, { 'for' => 'update' });
            #warn __PACKAGE__.$".Data::Dumper->Dump([\$exists], ['exists']);
            die "title\n" if $exists;
            my $cat = $schema->resultset('Category')->find($new_cat) or die "no_cat\n";
            my $info = $info_rs->create({
                    title      => $title,
                    created_by => $battie->get_session->userid,
                    ctime      => undef,
                    cat_id     => $cat->id,
                }) or
                $self->exception("Create", "Could not create gallery '$title'");
            my $id = $info->id;
            $battie->set_local_redirect('/gallery/edit/' . $id);
            $battie->writelog($info);
        };
        if ($@) {
            my $err = $@;
            $schema->txn_rollback;
            if ($err eq "no_cat\n") {
                $self->exception("Argument", "Category does not exist");
            }
            elsif ($err eq "title\n") {
                $self->exception("Argument", "'$title' already exists");
            }
            else {
                warn __PACKAGE__.':'.__LINE__.": !!! '$err'\n";
                die $err;
            }
        }
        else {
            $schema->txn_commit;
        }
        return;
    }
}

sub gallery__edit {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->exception("Argument", "Not a valid gallery id") if $id =~ tr/0-9//c;
    $self->init_db($battie);
    my $schema = $self->schema->{gallery};
    my $info = $schema->resultset('Info')->find($id);
    my $data = $battie->get_data;
    if (($submit->{save} or $submit->{set_cat}) and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{save}) {
        my $title = $request->param('gallery.title');
        $self->exception("Argument", "'$title' is not a valid title")
            unless WWW::Battie::Model::DBIC::Gallery->valid_title($title);
        $info->title($title);
        $info->update;
        $battie->set_local_redirect('/gallery/view/' . $id);
        $battie->writelog($info);
        return;
    }
    elsif ($submit->{set_cat}) {
        my $new_cat = $request->param('gallery.cat');
        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$new_cat], ['new_cat']);
        $schema->txn_begin;
        eval {
            my $cat = $schema->resultset('Category')->find($new_cat, { 'for' => 'update' })
                or die "Cat $new_cat not found";
            $info = $schema->resultset('Info')->find($id, { 'for' => 'update' })
                or die "Info $id not found";
            $info->update({
                cat_id => $new_cat,
            });
            $schema->txn_commit;
        };
        if ($@) {
            warn __PACKAGE__.':'.__LINE__.": Error $@\n";
            $schema->txn_rollback;
        }
        else {
            $battie->writelog($info, "Category $new_cat");
        }
        $battie->set_local_redirect('/gallery/edit/' . $id);
        return;
    }
    my $cats = $schema->set('Category', 'fetch_tree');

    my $info_ro = $info->readonly;
    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$info_ro], ['info_ro']);
    $data->{gallery}->{categories} = [$info->cat_id, map {
        [$_->id, ('- ' x ($_->level * 2)) . ' ' . $_->title] } @$cats
    ];
    $data->{gallery}->{info} = $info_ro;
}



sub gallery__edit_image {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my $submit = $request->get_submit;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($gid, $id) = @$args;
    $self->exception("Argument", "Not a valid gallery id") if $gid =~ tr/0-9//c;
    $self->exception("Argument", "Not a valid image id") if $id =~ tr/0-9//c;
    my $schema = $self->schema->{gallery};
    my $info_rs = $schema->resultset('Info');
    my $info = $info_rs->find($gid);
    my $info_ro = $info->readonly;
    $self->exception("Argument", "Gallery $gid does not exist") unless $info;
    my $data = $battie->get_data;
    $data->{gallery}->{info} = $info->readonly;
    my $image_rs = $schema->resultset('Image');
    my $image = $image_rs->find($id);
    $self->exception("Argument", "Image $id does not exist") unless $image;
    $self->exception("Argument", "Image $id does not exist in gallery $gid") if $gid != $image->info->id;
    $data->{gallery}->{image} = $image->readonly;
    # TODO $battie->valid_token
    if ($submit->{save} and not $battie->valid_token) {
        delete $submit->{save};
        $data->{gallery}->{error}->{token} = 1;
    }
    if ($submit->{delete} and not $battie->valid_token) {
        delete $submit->{delete};
        $data->{gallery}->{error}->{token} = 1;
    }
    if ($submit->{save}) {
        my $title = $request->param('image.title');
        my $position = $request->param('image.position');
        $image->title($title);
        $image->update;
        if ($position and $position != $image->position) {
            my $old_pos = $image->position;
            $position = int $position;
            if ($position < $old_pos) {
                my $smaller = $info->search_related(images =>
                    {
                        position => \" < $old_pos AND position >= $position",
                    },
                );
                $smaller->update({
                        position => \'position + 1',
                    });
            }
            else {
                my $bigger = $info->search_related(images =>
                    {
                        position => \" > $old_pos AND position <= $position",
                    },
                );
                $bigger->update({
                        position => \'position - 1',
                    });
            }
            $image->position($position);
            $image->update;
        }
        $battie->module_call(cache => 'delete_cache', "gallery/gallery/$gid");
        $self->delete_cached_pages($battie, $info_ro);
        $battie->set_local_redirect('/gallery/view/' . $gid);
        $battie->writelog($image, 'edit');
        return;
    }
    elsif ($submit->{delete}) {
        my $suffix = $image->suffix;
        my $dir = $battie->get_paths->{docroot} . $self->get_public_url;
        my $upload_dir = "$dir/$gid";
        my $file = "$upload_dir/$id.$suffix";
        my $tfile = "$upload_dir/thumbs/$id.$suffix";
        my $old_pos = $image->position;
        $image->delete or croak "Could not delete image $id";
        if (-f $file) {
            warn __PACKAGE__.$".Data::Dumper->Dump([\$file], ['file']);
            unlink $file or croak "Could not delete file '$file'";
            unlink $tfile or croak "Could not delete file '$tfile'";
        }
        $battie->set_local_redirect('/gallery/view/' . $gid);
        $info->image_count(\'image_count - 1');
        $info_ro->set_image_count($info_ro->image_count - 1);
        $info->update;
        my $bigger = $info->search_related(images =>
            {
                position => \" > $old_pos",
            },
        );
        $bigger->update({
                position => \'position - 1',
            });
        $battie->module_call(cache => 'delete_cache', "gallery/gallery/$gid");
        $self->delete_cached_pages($battie, $info_ro);
        $battie->writelog($info, 'delete image');
        return;
    }

    my $dir = $self->get_public_url;
    $data->{gallery}->{image_url} = $battie->get_paths->{docurl} . $dir;
}

sub gallery__edit_image_title {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my $submit = $request->get_submit;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($gid, $id) = @$args;
    $self->exception("Argument", "Not a valid gallery id") if $gid =~ tr/0-9//c;
    $self->exception("Argument", "Not a valid image id") if $id =~ tr/0-9//c;
    my $schema = $self->schema->{gallery};
    my $info_rs = $schema->resultset('Info');
    my $info = $info_rs->find($gid);
    $self->exception("Argument", "Gallery $gid does not exist") unless $info;
    my $data = $battie->get_data;
    if ($request->param('is_ajax')) {
        $data->{main_template} = "gallery/ajax.html";
        #return;
    }
    $data->{gallery}->{info} = $info->readonly;
    my $image_rs = $schema->resultset('Image');
    my $image = $image_rs->find($id);
    $self->exception("Argument", "Image $id does not exist") unless $image;
    $self->exception("Argument", "Image $id does not exist in gallery $gid") if $gid != $image->info->id;
    $data->{image} = $image->readonly;
    my $div_id = $request->param('div_id');
    $data->{div_id} = $div_id;
    $submit->{save} ||= $submit->{default};
    if ($submit->{save} and not $battie->valid_token) {
        delete $submit->{save};
        $data->{gallery}->{error}->{token} = 1;
    }
    if ($submit->{save}) {
        my $title = $request->param('image.title');
        #warn __PACKAGE__.$".Data::Dumper->Dump([\$title], ['title']);
        #sleep 5;
        $image->title($title);
        $image->update;
        $data->{image} = $image->readonly;
        $data->{saved} = 1;
        my $info_ro = $info->readonly;
        $self->delete_cached_pages($battie, $info_ro, $image->position);
        $battie->writelog($image);
    }
}

sub gallery__upload_image {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    $battie->response->set_no_cache(1);
    my $dir = $battie->get_paths->{docroot} . $self->get_public_url;
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my $submit = $request->get_submit;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->exception("Argument", "Not a valid gallery id") if $id =~ tr/0-9//c;
    my $schema = $self->schema->{gallery};
    my $info_rs = $schema->resultset('Info');
    my $info = $info_rs->find($id);
    $self->exception("Argument", "Gallery $id does not exist") unless $info;
    my $info_ro = $info->readonly;
    my $data = $battie->get_data;
    $data->{gallery}->{info} = $info->readonly;
    if ($submit->{upload} and not $battie->valid_token) {
        delete $submit->{upload};
        $data->{gallery}->{error}->{token} = 1;
    }
    if ($submit->{upload}) {
#        my $upload_id = $request->param('upload.id');
        warn __PACKAGE__." ===================== UPLOADING\n";
        #$self->write_upload_info($upload_id, 0);
        my $upload_dir = "$dir/$id";
        mkdir $upload_dir unless -d $upload_dir;
        my $thumbs = "$dir/$id/thumbs";
        mkdir $thumbs unless -d $thumbs;
        #warn __PACKAGE__.$".Data::Dumper->Dump([\$thumbs], ['thumbs']);
        my $image_rs = $schema->resultset('Image');
        my $inc = 0;
        for my $i (1..10) {
            my $filename = $request->get_cgi->param("gallery.image$i.file");
            my $upload = $request->get_cgi->upload("gallery.image$i.file");
            next unless $upload;
            my $title = $request->param("gallery.image$i.title");
            unless (defined $title and length $title) {
                #$title = "[no title]";
                $title = '';
            }
            #warn __PACKAGE__.$".Data::Dumper->Dump([\$upload], ['upload']);
            #my $upload_info = $request->get_cgi->uploadInfo($filename);
            #warn __PACKAGE__.$".Data::Dumper->Dump([\$upload_info], ['upload_info']);
            my $suffix = lc((split /\./, "$filename")[-1]);
            $suffix =~ tr/a-z0-9//cd;
            my $image = $image_rs->create({
                info => $id,
                title => $title,
                ctime => undef,
                suffix => $suffix,
                position => $info->image_count + $inc + 1,
            }) or
            $self->exception("Create", "Could not create image '$title'");
            my $iid = $image->id;
            my $imagefile = "$upload_dir/$iid.$suffix";
            open my $ifh, ">", $imagefile or croak "Could not write to '$imagefile': $!";
            binmode $ifh;
            while (my $line = <$upload>) {
                print $ifh $line;
            }
            close $ifh;
            my $thumbfile = "$thumbs/$iid.$suffix";
            File::Copy::copy($imagefile, $thumbfile);
            my ($resize, $new_x, $new_y) = $self->resize($imagefile, $self->get_scale);
            if ($resize) {
                my $gd = $resize->resize($new_x, $new_y);
                # TODO type
                my $png = $gd->png;
                open my $fh, '>', $thumbfile or die $!;
                binmode $fh;
                print $fh $png;
                close $fh;
            }
            $inc++;
        }
        if ($inc) {
            $info->image_count(\"image_count + $inc");
            $info->update;
            $info_ro->set_image_count($info_ro->image_count + $inc);
            $battie->writelog($info, "uploaded $inc pictures");
        }
        $battie->module_call(cache => 'delete_cache', "gallery/gallery/$id");
        $self->delete_cached_pages($battie, $info_ro);
        unless ($request->param('is_ajax')) {
            $battie->set_local_redirect('/gallery/upload_image/' . $id);
        }
        return;
    }
    else {
#        my @rand = ('a'..'z','A'..'Z',0..9);
#        my $rand = join '', time, map { $rand[rand @rand] } 1..20;
#        $data->{gallery}->{upload_id} = $rand;
    }
}

sub delete_cached_pages {
    my ($self, $battie, $info, $pos) = @_;
    my $id = $info->id;
    my $to_page;
    my $c = $pos ? $pos : $info->image_count;
    if ($c % $rows) {
        $to_page = ($c - $c % $rows) / $rows + 1;
    }
    else {
        $to_page = $c / $rows;
    }
    if ($pos) {
        $battie->module_call(cache => 'delete_cache', "gallery/images/$id/$to_page");
    }
    else {
        for my $p (1 .. $to_page) {
            $battie->module_call(cache => 'delete_cache', "gallery/images/$id/$p");
        }
    }
}


sub resize {
    my ($self, $file, $max) = @_;
    my $resize = Image::Resize->new($file);
    my ($x, $y) = ($resize->width, $resize->height);
    if ($x > $max or $y > $max) {
        my @new;
        if ($x > $y) {
            my $scale = $x / $max;
            my $new_x = $max;
            my $new_y = $y / $scale;
            @new = ($resize, $new_x, $new_y);
        }
        else {
            my $scale = $y / $max;
            my $new_y = $max;
            my $new_x = $x / $scale;
            @new = ($resize, $new_x, $new_y);
        }
        return @new;
    }
}

sub gallery__view {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->exception("Argument", "Not a valid gallery id") if $id =~ tr/0-9//c;
    my $page = $request->pagenum(1000);
    my $schema = $self->schema->{gallery};
    my $gallery = $battie->module_call(cache => 'from_cache', "gallery/gallery/$id");
    my $gallery_images = $battie->module_call(cache => 'from_cache', "gallery/images/$id/$page");
    my $info_ro;
    my $count;
    my $images;
    my $paths;
    if ($gallery) {
        $info_ro = $gallery->{info};
        $count = $gallery->{image_count};
        $paths = $gallery->{paths};
    }
    else {
        my $info_rs = $schema->resultset('Info');
        my $info = $info_rs->find($id);
        $self->exception("Argument", "Gallery $id does not exist") unless $info;
        $info_ro = $info->readonly;
        $gallery->{info} = $info_ro;
        $count = $schema->resultset('Image')->count({
            info => $id,
        });
        if ($info->cat_id) {
            my $cat = $schema->resultset('Category')->find($info->cat_id);
            $paths = $schema->select_path('Category' => $cat);
            $paths = [(map { $_->readonly } @$paths), $cat->readonly];
            $gallery->{paths} = $paths;
        }
        $gallery->{image_count} = $count;
        $battie->module_call(cache => 'cache', "gallery/gallery/$id", $gallery, 60 * 20);
    }
    my $pager = WWW::Battie::Pager->new({
            items_pp => $rows,
            total_count => $count,
            before => 3,
            after => 3,
            current => $page,
            link => $battie->self_url
                . '/gallery/view/' . $id . '?p=%p',
            title => '%p',
        })->init;
    $page = $pager->current;
    if ($gallery_images) {
        $images = $gallery_images->{images};
    }
    else {
        my $search = $schema->resultset('Image')->search(
            { info => $id },
            {
                    order_by => 'position ASC',
                    page => $page,
                    rows => $rows,
            });
        my $counter = 0;
        while (my $image = $search->next) {
            $counter++;
            my $ro = $image->readonly([qw/ id title suffix position ctime mtime /]);
            $ro->set_newline(1) if $counter % 4 == 0;
            push @$images, $ro;
        }
        $gallery_images->{images} = $images;
        $battie->module_call(cache => 'cache', "gallery/images/$id/$page", $gallery_images, 60 * 20);
    }
    my $data = $battie->get_data;
    my $dir = $self->get_public_url;
    $data->{gallery}->{image_url} = $battie->get_paths->{docurl} . $dir;
    $data->{gallery}->{info} = $info_ro;
    $data->{gallery}->{images} = $images;
    $data->{gallery}->{image_count} = $count;
    $data->{gallery}->{pager} = $pager;
    $data->{gallery}->{paths} = $paths;
    $data->{subtitle} = "gallery " . $info_ro->title;
}

sub gallery__list {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->init_db($battie);
    my $schema = $self->schema->{gallery};
    my $galleries = $schema->resultset('Info')->search(
        undef,
        {
            order_by => 'title asc',
        }
    );
    my $data = $battie->get_data;
    my %users;
    my @galleries;
    while (my $gallery = $galleries->next) {
        my $user = $battie->module_call(login => 'get_user_by_id', $gallery->created_by);
        my $first = $gallery->search_related(images => {
            position => 1,
        })->single;
        my $info_ro = $gallery->readonly;
        push @galleries, {
            info => $info_ro,
            created_by => $user ? $user->readonly : undef,
            first => $first ? $first->readonly : undef,
        };
    }
    $data->{gallery}->{list} = \@galleries;
    my $dir = $battie->get_paths->{docroot} . $self->get_public_url;
    $dir =~ s#^\Q$ENV{DOCUMENT_ROOT}##;
    $data->{gallery}->{image_url} = $dir;
}

sub gallery__cat2 {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{gallery};
    my $cat;
    if ($id) {
        $self->exception("Argument", "Not a valid image id") if $id =~ tr/0-9//c;
        $cat = $schema->resultset('Category')->find($id);
        $self->exception("Argument", "Category $id does not exist") unless $cat;
    }
    else {
        $cat = $schema->resultset('Category')->find({ left_id => 1 });
        unless ($cat) {
            $cat = $schema->resultset('Category')->create({
                title => 'root',
                parent_id => 0,
                left_id => 0,
                right_id => 0,
            });
        }
        $self->exception("Argument", "Root Category does not exist") unless $cat;
        $id = $cat->id;
    }
    my $paths = $schema->select_path('Category' => $cat);
    my ($children) = $schema->select_children('Category' => $id);
    my $data = $battie->get_data;
    my $cat_ro = $cat->readonly;
    $_ = $_->readonly for @$paths;
    for (@$children) {
        my @cats = $schema->resultset('Category')->search({
            left_id => { '>=' => $cat->left_id },
            right_id => { '<=' => $cat->right_id },
        })->all;

        my $count = $schema->resultset('Info')->count({
            cat_id => { -in => [map $_->id, @cats] }
        });
        $_ = {
            category => $_->readonly,
            gallery_count => $count,
        };
    }
    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$children], ['children']);
    $data->{gallery}->{category} = $cat_ro;
    $data->{gallery}->{paths} = $paths;
    $data->{gallery}->{children} = $children;
}

sub gallery__cat {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my ($id) = @$args;
    $id ||= 0;
    $self->exception("Argument", "Not a valid category id") if $id =~ tr/0-9//c;
    $self->init_db($battie);
    my $schema = $self->schema->{gallery};

    my $cat;

    my $submit = $request->get_submit;
    if (keys %$submit) {

        if ($id) {
            $cat = $schema->resultset('Category')->find($id);
            $self->exception("Argument", "Category $id does not exist") unless $cat;
        }
        else {
            $cat = $self->get_root_cat($battie);
            $id = $cat->id;
        }

        if ($submit->{create} and not $battie->valid_token) {
            $battie->token_exception;
        }
        if ($submit->{delete} and not $battie->valid_token) {
            $battie->token_exception;
        }
        if ($submit->{create}) {
            my $title = $request->param('cat.title');
            my $new_cat = $schema->insert_node('Category' => $id, {
                title => $title,
            });
            $battie->writelog($new_cat, "create");
            $battie->set_local_redirect('/gallery/cat/' . $new_cat->id);
            $battie->module_call(cache => 'delete_cache', "gallery/category/$id");
            return;
        }
        elsif ($submit->{delete}) {
            my $parent = $schema->set('Category', 'parent_node', $id);
            my $ro = $parent->readonly;
            $battie->module_call(cache => 'delete_cache', "gallery/category/" . $parent->id);
            my $deleted = $schema->delete_node('Category' => $id);
            $battie->writelog($cat, "delete");
            $battie->set_local_redirect('/gallery/cat/' . $cat->parent_id);
            return;
        }
    }
    else {
        my ($cat_ro, $paths, $children, $galleries);
        my $cat_info = $battie->module_call(cache => 'from_cache', "gallery/category/$id");
        if ($cat_info) {
            # in cache
            $cat_ro    = $cat_info->{cat};
            $paths     = $cat_info->{paths};
            $children  = $cat_info->{children};
            $galleries = $cat_info->{galleries};
        }
        else {
            if ($id) {
                $cat = $schema->resultset('Category')->find($id);
            }
            else {
                $cat = $self->get_root_cat($battie);
            }
            $cat_ro = $cat ? $cat->readonly : undef;
            @$paths = map { $_->readonly } @{ $schema->select_path('Category' => $cat) };
            ($children) = $schema->select_children('Category' => $id);
            $_ = $_->readonly for @$children;

            my $search = $schema->resultset('Info')->search(
                {
                    cat_id => $id,
                },
                {
                    order_by => 'title',
                },
            );
            while (my $info = $search->next) {
                my $user = $battie->module_call(login => 'get_user_by_id', $info->created_by);
                my $first = $info->search_related(images => {
                    position => 1,
                })->single;
                my $ro = $info->readonly;
                push @$galleries, {
                    info => $ro,
                    created_by => $user ? $user->readonly : undef,
                    first => $first ? $first->readonly : undef,
                };
            }
            $cat_info->{cat}       = $cat_ro;
            $cat_info->{paths}     = $paths;
            $cat_info->{children}  = $children;
            $cat_info->{galleries} = $galleries;
            $battie->module_call(cache => 'cache', "gallery/category/$id", $cat_info, 60 * 1);

        }
#        my $cat_counts = $self->fetch_category_counts($battie);
        my $data = $battie->get_data;
        $data->{gallery}->{category} = $cat_ro;
        $data->{gallery}->{paths} = $paths;
        $data->{gallery}->{children} = $children;
        $data->{gallery}->{infos} = $galleries;
        my $dir = $self->get_public_url;
        $data->{gallery}->{image_url} = $battie->get_paths->{docurl} . $dir;
    }
}

#sub fetch_category_counts {
#    my ($self, $battie) = @_;
#}

sub get_root_cat {
    my ($self, $battie) = @_;
    my $schema = $self->schema->{gallery};
    my $cat;
    $schema->txn_begin;
    eval {
        $cat = $schema->resultset('Category')->find({ left_id => 1 }, { 'for' => 'update' });
        unless ($cat) {
            $cat = $schema->resultset('Category')->create({
                title => 'root',
                parent_id => 0,
                left_id => 1,
                right_id => 2,
            });
        }
        $self->exception("Argument", "Root Category could not be created") unless $cat;
    };
    if ($@) {
        warn __PACKAGE__.':'.__LINE__.": Error $@\n";
        $schema->txn_rollback;
    }
    else {
        $schema->txn_commit;
    }
    return $cat;
}

sub gallery__view_image {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($gid, $id) = @$args;
    $self->exception("Argument", "Not a valid gallery id") if $gid =~ tr/0-9//c;
    $self->exception("Argument", "Not a valid image id") if $id =~ tr/0-9//c;
    $self->init_db($battie);
    my $schema = $self->schema->{gallery};
    my $info = $schema->resultset('Info')->find($gid);
    $self->exception("Argument", "Gallery $gid does not exist") unless $info;
    my $image = $schema->resultset('Image')->find($id);
    $self->exception("Argument", "Image $id does not exist") unless $image;
    $self->exception("Argument", "Image $id does not exist in gallery $gid") if $gid != $image->info->id;
    my $data = $battie->get_data;
    my $dir = $battie->get_paths->{docroot} . $self->get_public_url;
    $dir =~ s#^\Q$ENV{DOCUMENT_ROOT}##;
    $data->{gallery}->{image_url} = $dir;
    my $next = $info->search_related(images => {
            position => { '>' => $image->position },
        },
        {
            order_by => 'position ASC',
            rows => 1,
        }
    )->single;
    my $previous = $info->search_related(images => {
            position => { '<' => $image->position },
        },
        {
            order_by => 'position DESC',
            rows => 1,
        }
    )->single;
    if ($request->param('is_ajax')) {
        $data->{main_template} = "gallery/ajax.html";
        $data->{gallery}->{image} = $image->readonly;
        $data->{gallery}->{next_image} = $next ? $next->readonly : undef;
        $data->{gallery}->{previous_image} = $previous ? $previous->readonly : undef;
        return;
    }
    else {
    }
}
1;
