
use Modern::Perl;
use Kavorka -all;
use utf8;
use Carp::Assert;
use Data::Dumper;

binmode STDOUT, ":encoding(UTF-8)";

say 19;

say chr(0) x 8;

#my $message = chr(19) . "BitTorrent protocol" .  8 x chr(0) . $info_hash . $peer_id;
