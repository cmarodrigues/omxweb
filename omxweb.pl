#!env perl

use strict;
use utf8;

package Videos;

my $videos_dir = "/videos";

sub isValidVideoFilename {
    my ($video_fn) = @_;
    return 0 if( $video_fn =~ /^\./ );
    return 0 if( $video_fn =~ /Thumbs.db/ );
    return 0 if( $video_fn =~ /\.png$/i );
    return 0 if( $video_fn =~ /\.jpe?g$/i );
    return 0 if( $video_fn =~ /\.sub$/i );
    return 0 if( $video_fn =~ /\.srt$/i );
    return 0 if( $video_fn =~ /\.nfo$/i );
    return 0 if( $video_fn =~ /\.txt$/i );
    return 1;
}
sub getVideo {
    my ($video_dn) = @_;
    if( $video_dn !~ m/^\./ &&
        -d "$videos_dir/$video_dn" ){
        my $video_dir ="$videos_dir/$video_dn";
        my $video_title = $video_dn;
        opendir(VIDEO_DIR,"$video_dir");
        my @video_files = readdir(VIDEO_DIR);
        close(VIDEO_DIR);
        my ($video_file) = grep { !-d "$video_dir/$_" && isValidVideoFilename($_) } @video_files;
        my ($video_cover) = grep { /\.png$/ || /\.jpe?g$/ } @video_files;
        my ($video_sub) = grep { /\.sub$/ || /\.srt$/ } @video_files;
        my %V = ( 'title'=>$video_title, 'file'=>"$video_file", 'cover'=>"$video_cover", 'sub'=>"$video_sub", 'dir'=>"$video_dn", 'fullpath'=>"$video_dir/$video_file", 'coverpath'=>"$video_dir/$video_cover" );
        return wantarray() ? %V : \%V;
    }
    return;
}
sub list {
    my @list = ();
    if( -d "$videos_dir" ){
        opendir(VIDEOS_DIR,"$videos_dir");
        my @read_files = readdir(VIDEOS_DIR);
        for my $video_fn (@read_files){
            if( my $V = getVideo($video_fn) ){
                push @list, $V;
            }
        }
        close(VIDEOS_DIR);
    }
    return wantarray() ? @list : \@list;
}

1;

package Omxplayer;

my $omxplayer_cmd = "omxplayer -y -r -o hdmi -t on";

sub read_file {
    my ($file) = @_;
    open(READ_FILE,"$file");
    my @read_lines = ();
    while(<READ_FILE>){
        push(@read_lines,$_);
    }
    close(READ_FILE);
    return wantarray() ? @read_lines : \@read_lines;
}

sub isPlaying {
    if( my ($proc) = grep { !/grep/ && /omxplayer/ } read_file("ps fax |") ){
        my ($video_path) = ( $proc =~ m/$omxplayer_cmd (.+)/ );
        return wantarray() ? ( 'success'=>1, 'video_path'=>"$video_path" ) : 1;
    }
    return wantarray() ? ( 'success'=>0 ) : 0;
}

sub play {
    my ($video) = @_;

    if( !isPlaying() ){
        my $cmd = "$omxplayer_cmd \"$video\" &";
        my $e = system($cmd);
        return ($e==0) ? 1 : 0;
    }
    return 0;
}
sub stopall {
    my $e = system("killall omxplayer.bin");
    return ($e==0) ? 1 : 0;
}

1;

use Mojolicious::Lite;

my $url = 'http://localhost/';

my $http_host = $ENV{'HTTP_HOST'};
my @common = ( 'layout'=>'default', 'title'=>'omxplayer', 'keywords'=>'omxplayer,videos', 'description'=>'omxplayer', 'http_host'=>$http_host, 'url'=>$url );

hook before_dispatch => sub {
               # notice: url must be fully-qualified or absolute, ending in '/' matters.
               shift->req->url->base(Mojo::URL->new(q{http://$http_host/}));
          };


get '/' => sub { shift->render( 'index', @common ) };
get '/list' => sub { shift->render( 'list', @common ) };

get '/cover' => sub {
    my $self = shift;
    my $video_title = $self->param('video');
    my ($V) = grep { $_->{'title'} eq "$video_title" } Videos::list();
    if( $V && $V->{'cover'} ){
        my $conver_img = $V->{'coverpath'};
        return $self->render_static( $conver_img ) 
    }
};

get '/api/list' => sub {
    my $self = shift;
    return $self->render_json([ Videos::list() ]);
};
get '/api/isplaying' => sub {
    my $self = shift;
    my %c = Omxplayer::isPlaying();
    if( $c{'success'} ){
        if( my ($V) = grep { $_->{'fullpath'} eq "$c{'video_path'}" } Videos::list() ){
            $c{'video'} = $V; 
        }
    }
    return $self->render_json({ %c });
};
get '/api/play' => sub {
    my $self = shift;
    my $video_title = $self->param('video');
    my ($V) = grep { $_->{'title'} eq "$video_title" } Videos::list();
    if( $V ){
        return $self->render_json({ 'play'=>Omxplayer::play($V->{'fullpath'}) });
    }
};
get '/api/stopall' => sub {
    my $self = shift;
    return $self->render_json({ 'stopall'=>Omxplayer::stopall() });
};


app->start;

__DATA__

@@ not_found.html.ep
not found.

@@ index.html.ep
% layout 'default';

@@ list.html.ep
% layout 'default';
<div id="current-video"></div>
<div id="list-videos"></div>
<script type="text/javascript">
    $.getJSON('/api/isplaying',
        function(data) {
            if( data.success ){
                $('#current-video').append('You watching '+data.video.title+' ','<a class="button-stopall" href="#">Stop</a></div>');
                $('.button-stopall').click(function(){
                    $.getJSON('/api/stopall',function(){
                        location.reload();
                    });
                });
            }
        });
    $.getJSON('/api/list',
        function(data) {
            $.each(data, function(i,item){
                $('#list-videos').append($('<div class="video-box"/>').append('<div class="video-title">'+item.title+'</div>','<div class="video-cover">'+item.cover+'</div>','<div class="video-play"><a class="button-play" href="#">Play '+item.title+'</a></div>'));
                //$('#list-videos').append($('<div class="video-box"/>').append('<div class="video-title">'+item.title+'</div>','<div class="video-cover"><img src="/cover/'+item.title+'/'+item.cover+'" width="10px" height="10px"/></div>','<div class="video-play"><a class="button-play" href="#">Play '+item.title+'</a></div>'));
            });
            $('.button-play').click(function(){
                var video = $(this).text();
                video = video.replace('Play ','');
                $.getJSON('/api/play',{ 'video': video },
                            function(){
                                location.reload();
                            });
            });
        });

</script>

@@ cover.html.ep

@@ layouts/default.html.ep
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"> 
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="pt" lang="pt"> 
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" /> 
        <meta http-equiv="Content-language" content="pt" />
    	<meta name="url" content="<%= $url %>" /> 
        <meta name="description" content="<%= $description %>" /> 
        <meta name="keywords" content="<%= $keywords %>" /> 
        <meta name="robots" content="index,follow" />

        <title><%= title %></title>
        <link rel="stylesheet" type="text/css" href="css/main.css"></link>
        <script src="js/jquery.min.js"></script>
        <%= content_for 'header' %>
    </head>
    <body>
        <%= content %>
    </body>
</html>
