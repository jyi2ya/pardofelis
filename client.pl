#!/usr/bin/env perl

my %cfg = (
    server => 'http://127.0.0.1:48386',
    payload_size => 1024 * 78, # 78 KB
);

use utf8;
use warnings;

use HTTP::Tiny;
use MIME::Base64 qw/encode_base64/;
use JSON qw/encode_json decode_json/;
use Fcntl 'SEEK_CUR';

my $ua = HTTP::Tiny->new;

for my $filename (@ARGV) {
    open my $fd, '<', $filename or die;

    my $resp = $ua->post(
        "$cfg{server}/hello" => {
            content => encode_json {
                filename => $filename,
            }
        }
    );

    $resp = decode_json $resp->{content};

    my $last_report_time = time;

    my $id = $resp->{id};
    for (;;) {
        my $buf = undef;
        my $offset = sysseek $fd, 0, SEEK_CUR;
        my $len = sysread $fd, $buf, $cfg{payload_size};
        last if $len == 0;
        $ua->post(
            "$cfg{server}/take" => {
                content => encode_json {
                    id => $id,
                    offset => $offset,
                    payload => encode_base64 $buf,
                }
            }
        );

        if (time() - $last_report_time >= 3) {
            my $percentage = ($offset + $len) * 100 / (-s $filename);
            print "$percentage%\n";
        }
    }
}
