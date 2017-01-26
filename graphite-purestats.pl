#!/usr/bin/env perl
#
# A generic check to poll graphite data from Pure arrays.
# it reports overall and volume usage on arrays.
# 
# By: Phillip Pollard <phillip@purestorage.com>

use API::PureStorage;
use strict;

### Config

# pureadmin create --api-token
my %api_tokens = ( 
  'my-pure-array1.company.com' => 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
  'my-pure-array2.company.com' => 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
);

### Start 

my $client;
my $debug = 0;

for my $host ( sort keys %api_tokens ) {
  my $token = $api_tokens{$host};
  my $pure;

  eval { $pure = new API::PureStorage($host, $token); };
  if ($@) {
    warn "ERROR on $host : $@" if $debug;
    next;
  }

  ### Check the Array overall

  my $array_info = $pure->array_info();

  for my $param (qw/system capacity total/) {
    next if defined $array_info->{$param};
    die "Array data lacks parameter: $param";
  }

  print join(' ', "purity.$host.used", $array_info->{total},    time )."\n";
  print join(' ', "purity.$host.max",  $array_info->{capacity}, time )."\n";

  ### Check the volumes

  my $vol_info = $pure->volume_info();

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
}
