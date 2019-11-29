use Modern::Perl;
use Kavorka -all;
use utf8;
use EV;
use AnyEvent;
use Coro;
use Coro::AnyEvent;
use Digest::SHA1 qw(sha1);
use Encode;
use Bencode qw(bencode bdecode);
use Data::Dumper;
use LWP::Simple qw(get);

#binmode STDOUT, ":encoding(UTF-8)";

# TODO
# First make it work for ubuntu torrent, then make it work for any other torrent

fun torrent_file_content($file) {
    my $contents;
    open(my $fh, '<', $file) or die "Cannot open torrent file";
    {
        local $/; $contents = <$fh>;
    }
    close($fh);
    return $contents;
}


my $torrent_file = 'ubuntu-18.04.3-desktop-amd64.iso.torrent';
my $torrent = bdecode(torrent_file_content($torrent_file));

my $info_hash = Encode::encode("ISO-8859-1", sha1(bencode($torrent->{info})));
my $announce = $torrent->{'announce'};
my $port = 6881;
my $left = $torrent->{'info'}->{'length'};
my $uploaded = 0;
my $downloaded = 0;
my $peer_id = "-AZ2200-6wfG2wk6wWLc";

my $thr = $announce. "?info_hash=" . $info_hash . "&peer_id=" . $peer_id . "&port=" . $port . "&uploaded=" . $uploaded . "&downloaded=" . $downloaded . "&left=" . $left;

my $response = get($thr) or die "Cannot connect";
say Dumper bdecode($response);


EV::run();
