#!/usr/bin/perl
#This script was written to work with DynDNS servers
#but seems to be suitable for use with BIND9


use strict;
use warnings;

use Net::DNS;

# Your account info
my $key_name = "";
my $key_hmac = "";
my $host     = "";

# New IP address
my $ip = '1.2.3.4';

# DynDNS.com server information
my $tsig_server = 'update.dyndns.com';
my $tsig_server_pt = '53';

my $update = Net::DNS::Update->new($host);

$update->push("update", rr_add("$host A $ip"));
$update->sign_tsig($key_name, $key_hmac);

my $res = Net::DNS::Resolver->new(
	port => $tsig_server_pt,
	nameservers => [ $tsig_server ],
	debug => 0,
);

my $pack = Net::DNS::Packet->new(\($update->data));
my ($additional) = $pack->additional;

my $mac = $additional->mac;
my $mac_size = $additional->mac_size;

my $time = $pack->{additional}[-1]->time_signed;

my $reply = $res->send($update);

if ($reply) {
	if ($reply->header->rcode eq 'NOERROR') {
		print "Update succeeded, verifying source...";

		my $tsigRR = $reply->pop('additional');
		delete $reply->{additional};

		$reply->sign_tsig($key_name, $key_hmac);

		# Net::DNS::RR::TSIG should be handling this for us...
		my $size = unpack("H*", pack('n', $mac_size));

		$reply->{additional}[-1]->{request_mac} = $size . $mac;
		$reply->{additional}[-1]->{time_signed} = $time;

		my $packet = Net::DNS::Packet->new(\($reply->data));
		my ($additional) = $packet->additional;

		if ($additional->{mac} eq $tsigRR->{mac}) {
			print "Verified!\n";
		} else {
			print "Failed! Potential man in the middle attack!\n";
		}
	} else {
		$reply->additional;
		print 'Update failed: ', $reply->header->rcode, $reply->{additional}->[-1]->{error}, "\n";
	}
} else {
	print 'Update failed: ', $res->errorstring, "\n";
}
