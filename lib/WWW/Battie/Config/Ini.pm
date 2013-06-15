package WWW::Battie::Config::Ini;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(paths conf access db modules models layout antispam));
use Config::IniFiles;
use File::Spec;
use File::Basename;
use File::Spec;

my %ini;

sub create {
    my ($class, $file) = @_;
    if ($ini{ $file }) {
        return $ini{ $file };
    }
    warn __PACKAGE__.':'.__LINE__.": CREATE INI $file\n";
    my $cfg = Config::IniFiles->new(-file => $file);
    my $ini = {};
    my $view = $cfg->val(PATHS => 'VIEW');
    my $debug = $cfg->val(GENERAL => 'DEBUG');
    my $keywords = $cfg->val(GENERAL => 'KEYWORDS');
    my $timezone = $cfg->val(GENERAL => 'TIMEZONE') || "UTC";
    my $enable_https = $cfg->val(GENERAL => 'ENABLE_HTTPS');
    my $redir = $cfg->val(PATHS => 'REDIR');
    my $templates = $cfg->val(PATHS => 'TEMPLATES');
    my $server = $cfg->val(PATHS => 'SERVER');
    my $uploads = $cfg->val(PATHS => 'UPLOAD_INFO');
    my $tcache = $cfg->val(PATHS => 'TEMPLATE_CACHE');
    my $texpire = $cfg->val(PATHS => 'TEMPLATE_EXPIRE') || 60 * 60;
    #my $bbcode = $cfg->val(PATHS => 'BBCODE_IMAGES_DIR');
    my $bbcode_url = $cfg->val(PATHS => 'BBCODE_IMAGES_URL');
    my $docroot = $cfg->val(PATHS => 'BATTIE_DOCUMENT_ROOT');
    my $serverroot = $cfg->val(PATHS => 'BATTIE_SERVER_ROOT');
    my $docurl = $cfg->val(PATHS => 'BATTIE_ROOT_URL');
    my $default_page = $cfg->val(PATHS => 'DEFAULT_PAGE') || 'content/start';
    my $hompage_title = $cfg->val(PATHS => 'HOMEPAGE_TITLE') || 'battie';
    my $default_dbh = $cfg->val(PATHS => 'DEFAULT_DBH');
    my $default_table_prefix = $cfg->val(PATHS => 'DEFAULT_TABLE_PREFIX');
    my $google_api_key = $cfg->val(PATHS => 'GOOGLE_API_KEY');
    my $maintenance_file = $cfg->val(PATHS => 'MAINTENANCE_FILE');
    my $actionlog = $cfg->val(PATHS => 'ACTIONLOG');
    my $actionlog_format = $cfg->val(PATHS => 'ACTIONLOG_FORMAT')
        || '$EPOCH,$TS,$IP,$PID,$USER,$COOKIE,$REQUEST,$TIME,$PSIZE,$PSHARED';
    my $cgi_module = $cfg->val(PATHS => 'CGI_MODULE') || 'CGI';
    if ($cgi_module eq 'CGI::Simple') {
        # TODO
        # CGI::Simple has no upload hook functionality
        #require CGI::Simple;
        require CGI;
        require CGI::Simple::Cookie;
        require CGI::Simple::Util;
    }
    else {
        require CGI;
        require CGI::Cookie;
        require CGI::Util;
    }
    my $email_type = $cfg->val(EMAIL => 'TYPE') || 'sendmail';
    my $email_config = {
        from => $cfg->val(EMAIL => 'FROM'),
        type => $email_type,
    };
    if ($email_type eq 'smtp') {
        $email_config->{server} = $cfg->val(EMAIL => 'SERVER');
        $email_config->{user} = $cfg->val(EMAIL => 'USER');
        $email_config->{password} = $cfg->val(EMAIL => 'PASSWORD');
    }
    elsif ($email_type eq 'sendmail') {
        $email_config->{sendmail} = $cfg->val(EMAIL => 'SENDMAIL');
    }
    else {
        # debug
        my $logfile = $cfg->val(EMAIL => 'LOGFILE');
        unless (File::Spec->file_name_is_absolute($logfile)) {
            $logfile = File::Spec->catfile($serverroot, $logfile);
        }
        $email_config->{logfile} = $logfile;
    }

    my $base = dirname $file;
    $templates = [ map {
        File::Spec->file_name_is_absolute( $_ )
        ? $_
        : "$serverroot/$_"
    } split /;/, $templates ];
    my $includes = [];
    {
        my @param = $cfg->Parameters('INCLUDE');
        for my $item (@param) {
            my $file = $cfg->val(INCLUDE => $item);
            my $path = File::Spec->canonpath( File::Spec->catfile($base, $file) );
            #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$path], ['path']);
            push @$includes, $path;
        }
        
    }
    my $layout;
    {
        my @items = $cfg->GroupMembers("LayoutElement");
        for my $item (@items) {
            #warn __PACKAGE__." $item\n";
            my (undef, $name) = split ' ', $item;
            my @param = $cfg->Parameters($item);
            $layout->{$name} = {
                map { $_ => $cfg->val($item, $_) } @param
            }
        }
    }
    #my $auth;
    #{
    #    my $authen_class = $cfg->val(ACCESS => 'AUTHENTICATE');
    #    my @param = $cfg->Parameters("AUTHENTICATE $authen_class");
    #    $auth = {
    #        class => $authen_class,
    #        args => {
    #            map { $_ => $cfg->val("AUTHENTICATE $authen_class", $_) } @param,
    #        },
    #    };
    #}
    my $dsn = {};
    {
        my @items = $cfg->GroupMembers("DBH");
        for my $item (@items) {
            #warn __PACKAGE__." $item\n";
            my (undef, $name) = split ' ', $item;
            my @param = $cfg->Parameters($item);
            $dsn->{$name} = {
                map { $_ => $cfg->val($item, $_) } @param
            }
        }
    }
    my @antispam = $cfg->GroupMembers("ANTISPAM");
    my %antispam;
    for my $item (@antispam) {
        my (undef, $name)  = split ' ', $item;
        my $module = $cfg->val($item, 'MODULE');
        eval "require $module";
        if ($@) {
            warn __PACKAGE__.':'.__LINE__.": !!! $@\n" if $@;
            next;
        }
        my @param = $cfg->Parameters($item);
        my %args = map { $_ => $cfg->val($item, $_) } @param;
        my $obj = $module->initialize(%args);
        $antispam{$name} = $obj if $obj;
    }
    my %modules;
    my $use = '';
    {
        my @items = $cfg->GroupMembers("Module");
        for my $item (@items) {
            my (undef, $name) = split ' ', $item;
            next unless $name =~ m/^\w+(::\w+)*\z/;
            if (uc($cfg->val($item, 'ACTIVE')||'NO') ne 'YES') {
                next;
            }
            $use .= qq/require $name;\n/;
            my @param = $cfg->Parameters($item);
            $modules{$name} = {
                map { $_ => scalar $cfg->val($item, $_) } @param
            }

        }
    }
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$use], ['use']);
    eval $use;
    if ($@) {
        WWW::Battie->exception('Compile', "$@");
    }
    my %models;
    {
        my @items = $cfg->GroupMembers("Model");
        for my $item (@items) {
            my (undef, $name) = split ' ', $item;
            my @param = $cfg->Parameters($item);
            $models{$name} = {
                map { $_ => $cfg->val($item, $_) } @param
            };
            $models{$name}->{DBH} ||= $default_dbh;
            $models{$name}->{TABLE_PREFIX} ||= $default_table_prefix;

        }
    }
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$dsn], ['dsn']);
    unless (File::Spec->file_name_is_absolute($tcache)) {
        $tcache = File::Spec->catfile($serverroot, $tcache);
    }
    $ini = {
        conf => {
            debug           => $debug,
            enable_https    => $enable_https,
            timezone        => $timezone,
            keywords        => $keywords,
            template_expire => $texpire,
        },
        paths => {
            view => $view,
            view_original => $view,
            bbcode => $docurl . $bbcode_url,
            redir => $redir,
            templates => $templates,
            upload_info => $uploads,
            server => $server,
            template_cache => $tcache,
            default_page => $default_page,
            docroot => $docroot,
            serverroot => $serverroot,
            docurl => $docurl,
            homepage_title => $hompage_title,
            email => $email_config,
            google_api_key => $google_api_key,
            cgi_module => $cgi_module,
            maintenance_file => $maintenance_file,
            actionlog           => $actionlog,
            actionlog_format    => $actionlog_format,
        },
        db => $dsn,
        modules => \%modules,
        models => \%models,
        layout => $layout,
        antispam => \%antispam,
    };
    $ini{ $file } = $class->new($ini);
    return $ini{ $file };
}

sub load_all_classes {
    my ($self) = @_;
    my $models = $self->get_models;
    for my $module (keys %$models) {
        eval "use $module ()";
        if ($@) {
            warn __PACKAGE__." error loading $module: $@\n";
        }
        $module->load_classes_once;
    }
}


1;
