#!/usr/bin/perl

#This script is intended to dynamically update DNS  information 
#Using information from default network interface
#You should be aware that this script work only on hosts 
#With Internet ip address on default gateway interface

use strict;
use Net::Route::Table;
use IO::Interface::Simple;
use Term::ANSIColor;
use Net::DNS;
use Sys::Hostname::FQDN qw(
	short
	);
	

use Net::SNMP qw(:snmp);
use Net::IP;


my $IPADDR;

my $DEFAULT_INTERFACE;
my $_primary_server = 'cloud.msk.pp.ua.';
my $HOSTNAME=short();
my $ZONE = 'msk.pp.ua.';
my $key_name = 'ddns-update';
my $key_data = 'rj6C52Yz3woCrrkQCexkNlqkpY89HkvJNa71RLViI+f0k1K+bYHPCCImiaUueQBizximwPfHaLrpxWm8L7Dtqw==';


#Subroutines area 
#---------------------------------------------------------

sub get_modem_ext_ip {
	my $ipaddr;
my $hostname = '192.168.1.3';
my $read_community = 'home';
my $snmp_version = 1;

#my $snmp_timeout = 500;
my $snmp_session;
my $snmp_error;
my $snmp_result;

($snmp_session, $snmp_error) = Net::SNMP->session(
	-hostname => $hostname,
	-version => $snmp_version,
	-community => $read_community,

	);
	
if (!defined($snmp_session)) {
	printf "Error: Can't establish snmp session %s.\n", $snmp_error;
}

my $ip_addr_oid = '.1.3.6.1.2.1.4.20.1.1';
my @IP;
my    $counter = 0;
    my $_snmpOID;
    my @_snmpARGS = ( -varbindlist => [ $ip_addr_oid ] );
    while ( defined( $snmp_session->get_next_request(@_snmpARGS) ) ) {
        $_snmpOID = ( $snmp_session->var_bind_names() )[0];
        if ( !oid_base_match( $ip_addr_oid, $_snmpOID ) ) { last; }
        $IP[$counter] = $snmp_session->var_bind_list()->{$_snmpOID};
        $counter++;
        @_snmpARGS = ( -varbindlist => [$_snmpOID] );

    }
my $inet_persistance = 0;
	foreach $ipaddr (@IP) {
		my $ipobj = new Net::IP ($ipaddr) || die "Can't create IP object\n";
		if ($ipobj->iptype() eq 'PUBLIC') {
		print "Modem external IP address is " . $ipaddr . "\n";
		##print "IP type is " .  $ipobj->iptype() . "\n";
		$inet_persistance = 1;
		return $ipaddr;
	}
	
	}
	if ($inet_persistance == 0) {
		print STDERR "It seems modem lost internet connection\n";
		}
}


sub check_network_settings {
	my $table_ref = Net::Route::Table->from_system();
	my $route_ref = $table_ref->default_route();

	if (defined($route_ref)) {
		print "Default gateway interface: ", $route_ref->interface(), "\n";
		$DEFAULT_INTERFACE = IO::Interface::Simple->new($route_ref->interface());
	} else {
	  print STDERR "It seems your system does not have a default route.\n";
	}
	$IPADDR = $DEFAULT_INTERFACE->address;
	#print  $IPADDR . "\n";
}

sub check_resource_record {
	##my $res = Net::DNS::Resolver->new(
    ##		nameservers => [$_primary_server]
	##);
	my $res = Net::DNS::Resolver->new;
	$res->nameservers("$_primary_server");
	my $ip;
	print "Making new query for an A record of $HOSTNAME.$ZONE name\n";
	my $answer = $res->query("$HOSTNAME.$ZONE", 'A');
	if (!defined($answer)) { 
	    print "Looks like there is no such resource record\nI will try to add new one.";
	    my $update = Net::DNS::Update->new("$ZONE",'IN');
	    
	    
	    $update->push(prerequisite => nxrrset("$HOSTNAME.$ZONE A"));
	    $update->push(update => rr_add("$HOSTNAME.$ZONE 1H A $IPADDR"));
	    $update->push(addittional => Net::DNS::RR->new("$key_name TSIG $key_data"));
	    
	    
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
		  chomp $ip; print "Address: $ip $IPADDR\n";
		  if ($IPADDR eq $rr->address) {
		    print "IP address is still the same\n";
		  } else {
		    print "IP address was changed. So performing an update...\n";

		    my $update = Net::DNS::Update->new("$ZONE",'IN');
		    
		    
			$update->push(prerequisite => yxrrset("$HOSTNAME.$ZONE A")); 
			$update->push(update => rr_del("$HOSTNAME.$ZONE A")); 
			$update->push(update => rr_add("$HOSTNAME.$ZONE 300 A $IPADDR"));
			$update->push(addittional => Net::DNS::RR->new("$key_name TSIG $key_data")); 
			#$res->nameservers("$_primary_server");
		    
		    my $reply = $res->send($update);
		    
		    if($reply) {
			my $rcode = $reply->header->rcode;
			print 'Update ', $rcode eq 'NOERROR' ? "succeded\n" : "failed: $rcode\n";
		    } else {
			print 'Update failed (no reply): ', $res->errorstring, "\n";
		    }
		  }
		}
	}
}


#Main program area
#--------------------------------------------------------
check_network_settings;

my $defintIPobj = new Net::IP ($IPADDR) or die "Can't create IP object\n";
if ($defintIPobj->iptype() ne 'PUBLIC') {
	print "It seems you are behind a NAT\n";
	$IPADDR = get_modem_ext_ip();
	##print "Your modem external ip address is " . $IPADDR . "\n";
}

check_resource_record;

