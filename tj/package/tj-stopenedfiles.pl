#!/usr/bin/perl

use strict;
use warnings;

my $olddir = `pwd`;
$olddir =~ s/\s+$//g;

my $pidset = {};

sub setdefpidpwd
{
	my ($piddir, $pid) = @_;
	if (!exists $piddir->{$pid}) {
		$piddir->{$pid} = $olddir;
	}
}

sub abspath
{
	my ($d, $p) = @_;
	if ($p =~ /^\//) {
		return $p;
	}
	my $newdir = $d;
	$newdir =~ /\/+$/;
	while ($p =~ /^\.\.\//) {
		$newdir =~ s/^\/[^\/]+//g;
		$p =~ s/^\.\.\///g;
	}
	return $newdir .'/'. $p;
}

sub absdir
{
	my ($d, $p) = @_;
	if ($p =~ /^\//) {
		return $p;
	}
	if ($p eq '.') {
		return $d;
	}
	if ($p eq '..') {
		$p .= '/';
	}
	my $newdir = $d;
	$newdir =~ /\/+$/;
	while ($p =~ /^\.\.\//) {
		$newdir =~ s/^\/[^\/]+//g;
		$p =~ s/^\.\.\///g;
	}
	return $newdir . $p;
}

sub trimq
{
	my ($p) = @_;
	if ($p =~ /^"/ && $p =~ /"$/) {
		$p =~ s/^"//g;
		$p =~ s/"$//g;
	}
	return $p;
}

my $piddir = {};

while (<STDIN>) {
	my $s = $_;
	chomp $s;
	my $pid = '';
	my $call = '';
	my $p = '';
	if ($s =~ /^(\d+)\s+(\w+)\((\S+?)[,)]/) {
		#print join("\t", $1, $2, $3), "\n";
		$pid = $1;
		$call = $2;
		$p = $3;
		$p =~ s/,$//g;
	} elsif ($s =~ /(\d+)\s+<\.\.\.\s+clone\s+resumed>.+=\s+(\d+)/) {
		$pid = $1;
		$call = 'clone';
	}
	if ($pid) {
		setdefpidpwd($piddir, $pid);
		if ($s =~ /=\s+(\d+)$/) {
			my $ret = $1;
			if ($call eq 'open') {
				$p = trimq($p);
				if ($p ne '.') {
					my $d = $piddir->{$pid};
					#print STDERR join("\t", $pid, 'open', $p, $d, $s), "\n";
					print join("\t", abspath($d, $p), $s), "\n";
				}
			} elsif ($call eq 'chdir') {
				$p = trimq($p);
				if ($ret == 0) {
					my $d = $piddir->{$pid};
					my $newdir = absdir($d, $p);
					$piddir->{$pid} = $newdir;
					#print STDERR join("\t", 'chdir', $pid, $newdir, $s), "\n";
				}
			} elsif ($call eq 'clone') {
				if ($ret > 0) {
					my $chid = $ret;
					$pidset->{$chid} = $pid;
					my $d = $piddir->{$pid};
					$piddir->{$chid} = $d;
				}
			}
		}
	}
}
