#! /usr/bin/perl

use strict;
use warnings;

use experimental 'signatures';

use Getopt::Std;
use IO::Socket::INET;
use JSON::MaybeXS;

my %o=(p => 1705,
       h =>  $ENV{'MPD_HOST'} || 'localhost');
getopts('h:p:',\%o);

my $id=1;
my $status = getstatus();

my %cmd;
my @cc;
foreach my $param (@ARGV) {
  if ($param =~ /^(setup|setup_bystream|off|on)$/) {
    $cmd{$param} = 1;
  } elsif ($param =~ /^[0-9]+$/) {
    $cmd{latency} = $param;
  } else {
    push @cc, $param;
  }
}

if ($cmd{setup}) {
  my $d = 0;
  foreach my $gr (values %{$status->{group}}) {
    if (scalar @{$gr->{clients}} > 1) {
      jr('Group.SetClients',{
        id => $gr->{id},
        clients => [$gr->{clients}[0]],
      });
      $d = 1;
    }
  }
  if ($d) {
    $status = getstatus();
  }
  foreach my $gr (values %{$status->{group}}) {
    if (scalar @{$gr->{clients}} == 1 &&
        $gr->{name} ne $status->{client}{$gr->{clients}[0]}{name}) {
      jr('Group.SetName',{
        id => $gr->{id},
        name => $status->{client}{$gr->{clients}[0]}{name},
      });
    }
  }
} elsif ($cmd{off} || $cmd{on}) {
  my $mute = $cmd{off}?JSON()->true:JSON()->false;
  my %cc = map {$_ => 1} @cc;
  foreach my $gri (values %{$status->{group}}) {
    if (exists $cc{$gri->{name}}) {
      jr('Group.SetMute',{
        id => $gri->{id},
        mute => $mute,
      });
      delete $cc{$gri->{name}};
    }
  }
  foreach my $cli (values %{$status->{client}}) {
    if (exists $cc{$cli->{name}}) {
      jr('Client.SetVolume',{
        id => $cli->{id},
        muted => $mute,
      });
    }
  }
} elsif ($cmd{latency}) {
  my %cc = map {$_ => 1} @cc;
  foreach my $cli (values %{$status->{client}}) {
    if (exists $cc{$cli->{name}}) {
      jr('Client.SetLatency',{
        id => $cli->{id},
        latency => 0 + $cmd{latency},
      });
    }
  }
} elsif (@cc) {
  my @stream = grep {exists $status->{stream}{$_}} @cc;
  my %gi = map {$status->{group}{$_}{name} => $_} keys %{$status->{group}};
  my %ci = map {$status->{client}{$_}{name} => $_} keys %{$status->{client}};
  if (@stream) {
    foreach my $gri (map {$gi{$_}} grep {exists $gi{$_}} @cc) {
      if ($status->{group}{$gri}{stream} ne $stream[0]) {
        jr('Group.SetStream',{
          id => $gri,
          stream_id => $stream[0],
        });
      }
    }
  } else {
    my @cli = map {$ci{$_}} grep {exists $ci{$_}} @cc;
    my @gr = grep {!exists $ci{$_}} @cc;
    my $tgi = $status->{client}{$cli[0]}{group};
    if (exists $gi{$gr[0]}) {
      $tgi = $gi{$gr[0]};
      push @cli,@{$status->{group}{$tgi}{clients}};
      @cli = keys %{{map {$_ => 1} @cli}};
    }
    jr('Group.SetClients',{
      id => $tgi,
      clients => \@cli,
    });
    if ($status->{group}{$tgi}{name} ne $gr[0]) {
      jr('Group.SetName',{
        id => $tgi,
        name => $gr[0],
      });
    }
  }
} else {
  my %gi = map {$status->{group}{$_}{name} => $_} keys %{$status->{group}};
  foreach my $gn (sort keys %gi) {
    my $gid = $gi{$gn};
    print join('',
               $gn,
               $status->{group}{$gid}{muted}?'*':'',
               ' [',
               $status->{group}{$gid}{stream},
               ']: ',
               join(', ',map {
                 $status->{client}{$_}{name} .
                   ($status->{client}{$_}{latency}==0?'':'<'.($status->{client}{$_}{latency}).'>') .
                   ($status->{client}{$_}{muted}?'*':'')
                 } @{$status->{group}{$gid}{clients}}),
               "\n",
                 );
  }
}

sub getstatus {
  my $status=jr('Server.GetStatus');
  my %stream;
  foreach my $st (@{$status->{result}{server}{streams}}) {
    $stream{$st->{id}}=$st->{status};
  }

  my %group;
  my %client;
  foreach my $gr (@{$status->{result}{server}{groups}}) {
    my $gh = {
      id => $gr->{id},
      name => $gr->{name} || 'noname',
      stream => $gr->{stream_id},
      muted => $gr->{muted},
    };
    my $sid=$gr->{stream_id};
    foreach my $cl (@{$gr->{clients}}) {
      $client{$cl->{id}}={name => $cl->{host}{name},
                          id => $cl->{id},
                          group => $gr->{id},
                          muted => $cl->{config}{volume}{muted},
                          latency => $cl->{config}{latency},
                        };
      push @{$gh->{clients}},$cl->{id};
    }
    $group{$gh->{id}} = $gh;
  }
  return {
    stream => \%stream,
    group => \%group,
    client => \%client,
  };
}

sub jr($method,$params = undef) {
  my $client = IO::Socket::INET->new(
    PeerAddr => $o{h},
    PeerPort => $o{p},
    Proto => 'tcp',
      ) or die "no connect";

  my $call={
    jsonrpc => '2.0',
    id => $id++,
    method => $method,
  };
  if ($params) {
    $call->{params}=$params;
  }
  my $rq=encode_json($call);
  print $client "$rq\r\n";
  my $ret;
  while (<$client>) {
    $ret=$_;
    last;
  }
  $client->close;
  my $r = decode_json($ret);
  if (exists $r->{error}) {
    warn "Error on $method:\n";
    warn encode_json($params);
    foreach my $k (sort keys %{$r->{error}}) {
      warn "$k: $r->{error}{$k}\n";
    }
    die "\n";
  }
  return $r;
}
