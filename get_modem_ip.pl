#!/usr/bin/perl

#This script is intended to get External ip address from snmp compatible ADSL modem

use strict;
use Net::SNMP qw(:snmp);
use Net::IP;

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
	}
	
	}
	if ($inet_persistance == 0) {
		print "It seems modem lost internet connection";
		}

