#!/usr/bin/perl -w
#This is a simple test program in a new IDE

use strict;
use Net::DNS;

my $_ipaddress = '77.77.77.77';
my $_domain_name = 'chk.msk.pp.ua.';
my $_primary_server = 'cloud.msk.pp.ua.';
my $_zone = 'msk.pp.ua.';
my $key_name = 'ddns-update';
my $key_data = 'rj6C52Yz3woCrrkQCexkNlqkpY89HkvJNa71RLViI+f0k1K+bYHPCCImiaUueQBizximwPfHaLrpxWm8L7Dtqw==';
my $ip;
    
my $res = Net::DNS::Resolver->new;

my $answer = $res->query("$_domain_name", 'A');
if (!defined($answer)) { 
	print "Looks like there is no such resource record\nI will try to add new one.";
    my $update = Net::DNS::Update->new("$_zone",'IN');
    
    
    $update->push(prerequisite => nxrrset("$_domain_name A"));
    $update->push(update => rr_add("$_domain_name 1H A $_ipaddress"));
    $update->push(addittional => Net::DNS::RR->new("$key_name TSIG $key_data"));
    $res->nameservers("$_primary_server");
    
    my $reply = $res->send($update);
    
    if($reply) {
    	my $rcode = $reply->header->rcode;
    	print 'Update ', $rcode eq 'NOERROR' ? "succeded\n" : "failed: $rcode\n";
    } else {
    	print 'Update failed: ', $res->errorstring, "\n";
    }
} else {



foreach my $rr ($answer->answer) {
  next unless $rr->type eq 'A';
  $ip = $rr->address;
  chomp $ip;
  print "Address: $ip $_ipaddress\n";
  if ($_ipaddress eq $rr->address) {
    print "IP address is still the same\n";
  } else {
    print "IP address was changed. So performing an update...\n";

    my $update = Net::DNS::Update->new("$_zone",'IN');
    
    
	$update->push(prerequisite => yxrrset("$_domain_name A")); 
	$update->push(update => rr_del("$_domain_name A")); $update->push
	(update => rr_add("$_domain_name 1H A $_ipaddress")); $update->
	push(addittional => Net::DNS::RR->new("$key_name TSIG $key_data"
	)); $res->nameservers("$_primary_server");
    
    my $reply = $res->send($update);
    
    if($reply) {
    	my $rcode = $reply->header->rcode;
    	print 'Update ', $rcode eq 'NOERROR' ? "succeded\n" : "failed: $rcode\n";
    } else {
    	print 'Update failed: ', $res->errorstring, "\n";
    }
  }
}
}
