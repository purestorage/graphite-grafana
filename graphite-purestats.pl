#!/usr/bin/env perl
#
# A generic check to generate graphite input from Pure arrays.
# it reports overall and volume usage on arrays
# 
# By: Phil Pollard <phillip@purestorage.com>

use Data::Dumper;
use REST::Client;
use JSON;
use Net::SSL;
use strict;

### Config

my $cookie_file = "/tmp/statcookies.txt";

# pureadmin create --api-token
my %api_tokens = ( 
  'dogfood-alpo' => 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
  'dogfood-gravytrain' => 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
  'dogfood-snausage' => 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
);

our %ENV;
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

### Parse command line

my $debug = 0;

### Start RESTing

my $client;

for my $host ( keys %api_tokens ) {
  my $token = $api_tokens{$host};

  $client = REST::Client->new( follow => 1 );
  $client->setHost('https://'.$host);

  $client->addHeader('Content-Type', 'application/json');

  $client->getUseragent()->cookie_jar({ file => $cookie_file });
  $client->getUseragent()->ssl_opts(verify_hostname => 0);

  ### Check for API 1.4 support

  my $ref;
  eval '$ref = &api_get("/api/api_version")';
  warn $@ and next if $@;

  my %api_versions;
  for my $version (@{$ref->{version}}) {
    $api_versions{$version}++;
  }

  my $api_version = $api_versions{'1.4'} ? '1.4' :
                    $api_versions{'1.3'} ? '1.3' :
                    $api_versions{'1.1'} ? '1.1' :
                    $api_versions{'1.0'} ? '1.0' :
                    undef;

  if ( $debug and not $api_version ) {
    print STDERR "API is not supported on host: $host\n";
    next;
  }

  ### Set the Session Cookie

  my $ret = &api_post("/api/$api_version/auth/session", { api_token => $token });

  ### Check the Array overall

  my $array_info = &api_get("/api/$api_version/array?space=true");

  for my $param (qw/system capacity total/) {
    next if defined $array_info->{$param};
    die "Array data lacks parameter: $param";
  }

  print join(' ', "purity.$host.used", $array_info->{total},    time )."\n";
  print join(' ', "purity.$host.max",  $array_info->{capacity}, time )."\n";

  ### Check the volumes

  my $vol_info = &api_get("/api/$api_version/volume?space=true");

  for my $vol (@$vol_info) {
    for my $param (qw/total size name/) {
      next if defined $vol->{$param};
      die "Volume data lacks parameter: $param";
    }
  }

  for my $vol ( sort { ($b->{total}/$b->{size}) <=> ($a->{total}/$a->{size}) } @$vol_info) {
    print join(' ', "purity.$host.vol.$vol->{name}.used", $vol->{total}, time )."\n";
    print join(' ', "purity.$host.vol.$vol->{name}.max",  $vol->{size},  time )."\n";
  }  

  # Kill the session

  $ret = $client->DELETE("/api/$api_version/auth/session");
  unlink($cookie_file);
}

### Subs

sub api_get {
  my $url = shift @_;
  my $ret = $client->GET($url);
  my $num = $ret->responseCode();
  my $con = $ret->responseContent();
  if ( $num == 500 ) {
    die "API returned error 500 for '$url' - $con\n";
  }
  if ( $num != 200 ) {
    die "API returned code $num for URL '$url'\n";
  }
  print STDERR 'DEBUG: GET ', $url, ' -> ', $num, ":\n", Dumper(from_json($con)), "\n" if $debug;
  return from_json($con);
}

sub api_post {
  my $url = shift @_;
  my $con = shift @_;
  my $ret = $client->POST($url, to_json($con));
  my $num = $ret->responseCode();
  my $con = $ret->responseContent();
  if ( $num == 500 ) {
    die "API returned error 500 for '$url' - $con\n";
  }
  if ( $num != 200 ) {
    die "API returned code $num for URL '$url'\n";
  }
  print STDERR 'DEBUG: POST ', $url, ' -> ', $num, ":\n", Dumper(from_json($con)), "\n" if $debug;
  return from_json($con);
}
