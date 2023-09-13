#!/usr/bin/env perl

my %cfg = (
    mode => 'production',
    address => '127.0.0.1',
    port => '48386',
);

use Mojolicious::Lite -signatures;
use Mojo::Util qw/b64_decode/;

use v5.20;
use utf8;
use warnings;
use feature 'signatures';

use Fcntl 'SEEK_SET';

helper tasks => sub {
    use Mojo::Cache;
    state $box = Mojo::Cache->new;
};

post '/take' => sub ($c) {
    $c->render(text => '');
    my $req = {
        id => '$',
        offset => '$',
        payload => '$',
    };

    $req = $c->req->json;
    my ($id, $offset, $payload) = @{ $req }{'id', 'offset', 'payload'};
    my $data = b64_decode $payload;

    my $task = $c->tasks->get($id);
    my $fd = $task->{fd};
    sysseek $fd, $offset, SEEK_SET;
    syswrite $fd, $data;
};

post '/hello' => sub ($c) {
    use Data::UUID;
    state $gen = Data::UUID->new;

    my $req = {
        filename => '$',
    };

    $req = $c->req->json;

    my $id = $gen->create_str;
    open my $fd, '>', $req->{filename};

    my $task = {
        id => $id,
        fd => $fd
    };

    $c->tasks->set(
        $id => $task
    );

    $c->render(
        json => {
            id => $id
        }
    );
};

app->mode($cfg{mode});
app->start(
    'daemon',
    '-l', "http://$cfg{address}:$cfg{port}"
);
