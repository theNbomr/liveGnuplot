#! /usr/bin/perl -w 
use strict;

# ========================================================
#   Useful links for understanding this code and for 
#   learning Channel Access programming in general
#
#   https://epics.anl.gov/docs/AES2013/12-CA_APIs.pdf
#   https://epics.anl.gov/base/R3-15/4-docs/CA.html
#
# ========================================================


use lib '/usr1/local/epics/base-3.16/epics-base/lib/perl';
use CA;

    # print "\@INC : ", join( "\n", @INC ), "\n";

    print "EPICS_CA_REPEATER_PORT: $ENV{ EPICS_CA_REPEATER_PORT }\n";
    print "EPICS_CA_SERVER_PORT:   $ENV{ EPICS_CA_SERVER_PORT }\n";

    $ENV{EPICS_CA_REPEATER_PORT} = 9101;
    $ENV{EPICS_CA_SERVER_PORT} = 9102;

    my $pv = 'RN:TEST1:CALC1.CALC';
    if( @ARGV ){
        $pv = shift;
        # print "Commandline PV: $pv\n";
    }

    my $chan = CA->new( $pv );
    CA->pend_io(1);
    my @access = ('no ', '');
    printf "    PV name:       %s\n", $chan->name;
    printf "    Data type:     %s\n", $chan->field_type;
    printf "    Element count: %d\n", $chan->element_count;
    printf "    Host:          %s\n", $chan->host_name;
    printf "    State:         %s\n", $chan->state;
    printf "    Access:        %sread, %swrite\n",
        $access[$chan->read_access], $access[$chan->write_access];

    die "PV not found!" unless $chan->is_connected;
    $chan->get;
    CA->pend_io(1);
    printf "    Value:         %s\n", $chan->value;

    # print "chid: $chan \n";
    # print "chid: ", join( ", ", sort keys %{ $chan } ),"\n";
    $chan->create_subscription('v', \&callback, 'DBR_TIME_DOUBLE');
    # CA->pend_event(10);
    # pend_event(0) blocks forever...
    CA->pend_event(1.0);
    print "Done\n";

    while( 1 ){
        CA->pend_event(0.001);
        #
        #   We don't seem to lose monitors during the sleep;
        #    we just don't catch them in a timely manner...
        #
        sleep(10);
    }




sub callback {
    my ($chan, $status, $data) = @_;


    # print join( ", ", sort keys %{ $chan } ), "\n";
    if ($status) {
        printf "%-30s %s\n", $chan->name, $status;
    } else {
        printf "    Value:         %g\n", $data->{value};
        printf "    Timestamp:     %d.%09d\n",
            $data->{stamp}, $data->{stamp_fraction};
        if( defined( $data->{severity} ) ){
            printf "    Severity:      %s\n", $data->{severity};
        }
    }
    # print join( ", ", sort keys %{ $data } ), "\n\n";
}

