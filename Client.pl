use Modern::Perl;
use Kavorka -all;
use utf8;
use POSIX;
use EV;
use AnyEvent;
use Coro;
use Coro::AnyEvent;
use AnyEvent::Socket;
use Coro::Handle;
use Digest::SHA1 qw(sha1);
use JSON::XS;
use Encode;
use Bencode qw(bencode bdecode);
use Data::Dumper;
use LWP::Simple qw(get);


# TODO:
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

my $info_hash  = Encode::encode( "ISO-8859-1", sha1( bencode( $torrent->{info} ) ) );
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

my $response = get($thr) or die "Cannot connect to tracker";
my $tracker_response = bdecode($response);

my $peers = $tracker_response->{'peers'};

# $peers - {port, peert id, ip}

my $pstr = "BitTorrent protocol";
my $message = pack 'C1A*a8a20a20', length($pstr), $pstr, '',  $info_hash, $peer_id;

say $message;

my $bitfields_num = length($torrent->{info}->{pieces}) / 20;
my $bitfield_num_bytes = 4 + 1 + ceil($bitfields_num / 8);

# length - 4 bytes, id - 1 bytes,
# $bitfields_num / 8 - bitfields bytes

my $piece_channel = new Coro::Channel;
for my $n (0..$bitfields_num) {
    $piece_channel->put($n);
}

my $data_channel = new Coro::Channel;

# put piece data in json format,
# {piece_num, piece_data, piece_percent, piece_size}

# TODO:
# get piece number from piece_channel,
# download and put in $data_channel,
# if piece doesnt exists on the peer,
# put piece number back on to piece_channel,
# other worker may download it.

for my $n (0..5) {
    async {
        tcp_connect $peers->[$n]->{'ip'}, $peers->[$n]->{'port'}, Coro::rouse_cb;
        my $fh = unblock +(Coro::rouse_wait)[0];

        my $buf;
        my $bitfield;

        $fh->syswrite($message);
        $fh->sysread($buf, length($message));
        $fh->sysread($bitfield, $bitfield_num_bytes);

        my ($pstr_r, $reserved_r, $info_hash_r, $peer_id_r, $c) = unpack 'C/a a8 a20 a20 a*', $buf;
        my ($bitfield_length, $bitfield_id, $bitfield_data) = unpack 'N1 C1' . ' B' . $bitfields_num, $bitfield;

        if( $info_hash eq $info_hash_r ) {
            my $interested =  pack('Nc', 1, 2);
            my $choke_buf;

            $fh->syswrite($interested);
            $fh->sysread($choke_buf, 5);

            my ($len, $id) = unpack 'Nc', $choke_buf;
            if( $id == 1 ) {    # Got Unchoke
                # ...
            }

        }
    };
}

async {
    while (1) {
        Coro::AnyEvent::sleep 60;

        if( $piece_channel->size == 0 ) {
            # get data from $data_channel, arrange it in order and write that to a file
        }
    }
};

my @lines;
my $idle_w;
my $io_w = AnyEvent->io (fh => \*STDIN, poll => 'r', cb => sub {
    my $size;
    my $percent;
    push @lines, scalar <STDIN>;
    $idle_w ||= AnyEvent->idle (cb => sub {
       if (my $line = shift @lines) {
          chomp($line);
          if( $line eq "off" ) {
              say "Preparing for turn off";
              # write data from $data_channel to a file and kill
          }
          if( $line eq "status" ) {
              $size = $data_channel->size;
              $percent = $size * 100 / $bitfields_num;
              say "$percent % done";
          }
       } else {
             undef $idle_w;
       }
    });
});

cede;
EV::loop();
