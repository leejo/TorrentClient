use Modern::Perl;
use Kavorka -all;
use utf8;
use EV;
use AnyEvent;
use Coro;
use Coro::AnyEvent;
use AnyEvent::Socket;
use Coro::Handle;
use Digest::SHA1 qw(sha1);
use Encode;
use Bencode qw(bencode bdecode);
use Data::Dumper;
use LWP::Simple qw(get);
use Carp::Assert;

# TODO
# 1. make it work for ubuntu torrent

fun torrent_file_content($file) {
    my $contents;
    open( my $fh, '<', $file ) or die "Cannot open torrent file";
    {
        local $/;
        $contents = <$fh>;
    }
    close($fh);
    return $contents;
}

my $torrent_file = 'ubuntu-18.04.3-desktop-amd64.iso.torrent';
my $torrent      = bdecode( torrent_file_content($torrent_file) );

my $info_hash =
  Encode::encode( "ISO-8859-1", sha1( bencode( $torrent->{info} ) ) );
my $announce   = $torrent->{'announce'};
my $port       = 6881;
my $left       = $torrent->{'info'}->{'length'};
my $uploaded   = 0;
my $downloaded = 0;
my $peer_id    = "-AZ2200-6wfG2wk6wWLc";

my $thr =
    $announce
  . "?info_hash="
  . $info_hash
  . "&peer_id="
  . $peer_id
  . "&port="
  . $port
  . "&uploaded="
  . $uploaded
  . "&downloaded="
  . $downloaded
  . "&left="
  . $left;

my $response         = get($thr) or die "Cannot connect to tracker";
my $tracker_response = bdecode($response);

my $peers = $tracker_response->{'peers'};   # {port, peert id, ip}

my $pstr = "BitTorrent protocol";
my $message = pack 'C1A*a8a20a20', length($pstr), $pstr, '',  $info_hash, $peer_id;

for my $n (0..5) {
    async {
        tcp_connect $peers->[$n]->{'ip'}, $peers->[$n]->{'port'}, Coro::rouse_cb;
        my $fh = unblock +(Coro::rouse_wait)[0];

        my $buf;

        $fh->syswrite($message);
        $fh->sysread($buf, 200);

        my ($pstr_r, $reserved_r, $info_hash_r, $peer_id_r) = unpack 'C/a a8 a20 a20', $buf;

        say "Peer < $n > info hash: ", $info_hash_r;
        say "Peer < $n > id: ", $peer_id_r;
    };
}


cede;
EV::loop();
