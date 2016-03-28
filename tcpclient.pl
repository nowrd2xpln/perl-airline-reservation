#!/usr/bin/perl 
#
# CMPE 207 Project - Distributed Airline System
# Client Code
# Spring 2012 
#
#
######################  TCP/IP Client  #########################

use strict;

#
# Set up the socket
#
use IO::Socket;

#
# Could use IO::Socket::SSL if installed
#
# IO::Socket::SSL


#
# Read command line args for host and port
#
my $host;
my $port;
if ($#ARGV == 1) {
    $host = $ARGV[0];
    $port = $ARGV[1];
} else {
    #
    # default host/port
    #
    $host = "localhost";
    $port = "3689";
}

#
# create socket
#
my $socket = IO::Socket::INET->new(PeerAddr => $host,
                               PeerPort => $port,
                               Proto    => 'tcp',
                               Type     => SOCK_STREAM)
                      or
die "Cannot open socket!\n";

#
# SSL if installed
#
#my $socket = IO::Socket::SSL->new(PeerAddr => $host,
#                               PeerPort => $port,
#                                Proto    => 'tcp',
#                                Type     => SOCK_STREAM)
#                      or
#die "Cannot open socket!\n";
#

#
# Global variable declarations
#
my $outbuf;
my $inbuf;
my $login_name;
my $login_password;
my $outstream;
my $debug = 0;
my $quit_flag = 1;
my $agent_airline = "";

$SIG{PIPE} = 'handler';    #  SIGPIPE if server end of socket is gone when                                 #  we try to write to it.

#  Trap terminal signals so that we can send a quit packet to the server.
$SIG{INT}  = 'handler';  
$SIG{QUIT} = 'handler'; 

while ($quit_flag) {
    #
    # Receive user input
    #
    printMenu();
    print"Enter option[1-4]: ";
    $outbuf = <STDIN>;

    #
    # Determine what type of user to
    # handle and call appropriate
    # function
    #
    if (validate($outbuf)) {
        if ($outbuf == 1) {
            manageAdmin(); 
        } elsif ($outbuf == 2) {
            manageAgent();
        } elsif ($outbuf == 3) {
            initialClient();
        } else {
            $quit_flag = 0;
        } 
    } 
}
close ($socket);
exit 1;

#
# Print menu
#
sub printMenu() {

    print "-----------------------------------\n";
    print " Distributed Airline System v1.0\n\n";
    print "    Login as [1-4]:\n";
    print "    1) Administrator\n";
    print "    2) Airline Agent\n";
    print "    3) Customer\n";
    print "    4) Exit\n";
    print "-----------------------------------\n";

}

#################################
#
# Generic user login function
# that serves admin, customer and
# travel agent login authentication
#
# Takes user input for login name and
# password and sends both in a output
# stream to the server for authentication
#
#################################
sub user_login(@) {
    my $type = shift;
    my $airline = "";

    #
    # Obtain user input 
    #
    print "User: ";
    $login_name = <STDIN>;

    print "\nPassword: ";
    #
    # Hide password as it is typed
    # 
    system('stty','-echo');
    $login_password=<STDIN>;
    print "\n";
    system('stty','echo');

    #
    # If called from agent function
    # also ask for agent airline
    #   
    if ($type == 2) {
        print "Airline: ";
        $airline = <STDIN>;
	$agent_airline = $airline;
	chomp($agent_airline);
    }

    #
    # Construct stream to send to server
    # 
    chomp($login_name);
    if ($type == 2) {
        chomp ($login_password);
        $outstream = "$login_name:$login_password:$airline";
    } else {
        $outstream = "$login_name:$login_password";
    }

    print $socket $outstream; # send user login to server 
    $inbuf = <$socket>; # receive output from server 
    chomp $inbuf;

    # 
    # Verify correct handling of credentials
    #
    if ($inbuf eq "ACK") {
        print "Login successful\n";
        return 1;
    } else {
        print "Server Message: $inbuf\n";
        return 0;
    }
}

#
# General purpose function for user creation
# used by admin, agent and customer functions
#
sub user_creation(@) {
    my $type = shift;
    my $airline = "";
    my $fname = "";
    my $lname = "";
    #
    # Obtain username and password
    #
    print "\nUsername/Password Creation Guidlines:\n";
    print "    Please only use alphabetical characters\n";
    print "    to create username and password.\n\n";
    print "Desired username: ";
    $login_name = <STDIN>;
    print "Desired password: ";
    $login_password = <STDIN>;
    if ($type == 2) {
        print "Airline: ";
        $airline = <STDIN>;
    }    
    
    print "First Name: ";
    $fname = <STDIN>;
    print "Last Name: ";
    $lname = <STDIN>;

    #
    # Send new user data to server
    #
    chomp($login_name);
    chomp($login_password);
    chomp($fname);

    #
    # Construct string to send to server
    #
    if ($type == 2) {
        chomp($lname);
        $outstream = "$login_name:$login_password:$fname:$lname:$airline";
    } else {
        $outstream = "$login_name:$login_password:$fname:$lname";
    }
    print $socket $outstream;
    
    #
    # Receive ack from server
    #
    $inbuf = <$socket>;
    chomp($inbuf);
    
    if ($inbuf eq "ACK") {
        print "Created new user $login_name\n";
        return 1;
    } else {
        print "Server Message: $inbuf\n";
        return 0;
    }
    
}

#
# root function to handle all admin. functions
#
sub manageAdmin() {
    my $c_flag = user_login(1);
    while ($c_flag) {

	#
	# Show menu
	#
    	print "----------------------------------\n";
    	print " Airport System Administrator Menu\n";
    	print "     Select option [1-7]:\n";
    	print "     1) View all flights\n";
    	print "     2) View all reservations\n";
    	print "     3) Add flight\n";
    	print "     4) Modify flight\n";
    	print "     5) Delete flight\n";
    	print "     6) Add airline agent\n";
        print "     7) Exit\n";
    	print "----------------------------------\n";

    	print "Option: ";
    	$outbuf = <STDIN>;

	#
	# Wait for server to validate option
	#
    	if (validate($outbuf)) {
        	SWITCH:
		{
		    #
		    # view all flights
		    #
	    	    $outbuf =~ /1/ && do
	    	    {
			view_flights(1);
	        	last SWITCH;
	            };

		    #
		    # view all reservations
		    #
	    	    $outbuf =~ /2/ && do
	    	    {
			view_reservations(1,1);
	        	last SWITCH;
	            };

	    	    #
	    	    # Add new flight into airport
	    	    #
	    	    $outbuf =~ /3/ && do
	    	    {
			add_flight();
	        	last SWITCH;
	    	    };

		    #
		    # modify flight
		    #
	    	    $outbuf =~ /4/ && do
	    	    {
			view_flights(1);
  			modify_flight();
	         	last SWITCH;
	    	    };
		    
		    #
		    # delete flight
		    #
	    	    $outbuf =~ /5/ && do
	    	    {
		   	view_flights(5);
			delete_flight();
	          	last SWITCH;
	    	    };
	    
	    	    #
            	    # Create agent
     	    	    #
	    	    $outbuf =~ /6/ && do
	    	    { 
	        	user_creation(2); # create agent
	        	last SWITCH;
	    	    };

		    #
		    # Exit
		    #
	    	    $outbuf =~ /7/ && do
	    	    {
  			$c_flag = 0;
	        	last SWITCH;
	            };

		}
    	}
    }
}

#
# Called by admin function to modify flight fields
#
sub modify_flight() {

    my $flight_id;
    my $value;

    print "Enter flight entry # to modify: ";
    $flight_id = <STDIN>;

    # send entry # to server
    print $socket $flight_id;

    #print menu
    print "-----------------------------------\n";
    print " Select Field to Modify\n\n";
    print "    Select option [1-9]:\n";
    print "    1) Airline \n";
    print "    2) Flight number \n";
    print "    3) Number of seats \n";
    print "    4) Terminal \n";
    print "    5) Departure city \n";
    print "    6) Arrival city\n";
    print "    7) Departure time \n";
    print "    8) Arrival time \n";
    print "    9) Date of flight \n";
    print "-----------------------------------\n";

    print "Enter option: ";
    $outbuf = <STDIN>;

    if (validate($outbuf)) {
        print "Enter new value: ";
        $value = <STDIN>;

	#	
        # send value to server
        #
	print $socket $value;

	#
	# receive response
	#
	$inbuf = <$socket>;
        chomp($inbuf);
        if ($inbuf eq "ACK") {
	    print "Updated field successfully\n";
	} else {
	    print "Server Error: $inbuf\n";
	}
    }
}

#
# Called by admin function to delete a flight 
# from flights db
#
sub delete_flight() {

    my $entry;

    # ask for specific flight ID
    print "Enter flight entry # to remove: ";
    $entry = <STDIN>;
    
    # send to server to delete
    print $socket $entry;
    chomp($entry);

    # confirm deletion
    $inbuf = <$socket>;
    chomp($inbuf);

    if ($inbuf eq "ACK") {
  	print "Successfully deleted flight ID: $entry\n";
    } else {
        print "Server Error: $inbuf\n";
    }
}

#
# root function used to manage all agent activities
#
sub manageAgent() {
    my $c_flag = user_login(2);
    my $user;

    while ($c_flag) {

        #
    	# Menu
    	#
        print "-----------------------------------\n";
    	print " Airline Agent Menu\n\n";
    	print "    Select option [1-5]:\n";
    	print "    1) View flights \n";
    	print "    2) Add reservation \n";
    	print "    3) View reservations \n";
    	print "    4) Delete reservation \n";
    	print "    5) Exit\n";
    	print "-----------------------------------\n";

    	print "Option: ";
    	$outbuf = <STDIN>;

    	if (validate($outbuf)) {
	    SWITCH:
	    {
		#
		# view all flights particular to agent
		#
		$outbuf =~ /1/ && do {
		    view_flights(2);
		    last SWITCH;
		};

		#
		# add reservation for airline
		#
		$outbuf =~ /2/ && do {
		    view_flights(2);
		    add_reservation(2);
		    last SWITCH;
		};

		#
		# view reservations under this airline
		#
		$outbuf =~ /3/ && do {
		    view_reservations(2,1);
		    last SWITCH;
		};

		#
		# delete a reservation
		#
		$outbuf =~ /4/ && do {
		    view_flights(4);
	     	    $user = view_reservations(2,0);
		    delete_reservation($user);
		    last SWITCH;
		};

		#
		# exit
		#
		$outbuf =~ /5/ && do {
		    $c_flag = 0;
		    last SWITCH;
		};
	    }
	}
    }
}

#
# General purpose function used to delete reservations.
# Used by both agent and customer functions.
#
sub delete_reservation(@) {
    my $user = shift;
    my $entry;
    
    chomp($user); 

    print "Enter reservation ID #: ";
    $entry = <STDIN>;

    # send user/flight id to server to process
    print $socket "$user:$entry";

    $inbuf = <$socket>;
    chomp($inbuf);

    if ($inbuf eq "ACK") {
        print "Successfully deleted reservation\n";
    } else {
	print "Error: $inbuf\n";
    }

}

#
# General purpose function to view reservations.
# Special cases for admin, agent and customer.
#
sub view_reservations(@) {
    my $type = shift;
    my $displayAll = shift;
    my $user;
    
    #
    # Handle special cases
    #
    if (!$displayAll) {
        if ($type == 2) {
            print "Enter customer username: ";
            $user = <STDIN>;
        } else {
            $user = "$login_name\n";
        }
    } else {
        $user = "default_all\n";
    }

    #
    #  List all flights for particular airline
    #     -send login name/airline for sql query
    #
    $outbuf = "$agent_airline:$user"; 
    print $socket $outbuf;
   
    $inbuf = <$socket>;
    chomp($inbuf);

    #
    # if flight entry exists...
    #
    if ($inbuf eq "ACK") {    
        if ($type < 4) {
	    #
	    # receive data from server to display
	    #
            print "\n ---List of Reservations---\n";
            $inbuf = <$socket>;	
            chomp($inbuf);
            while (!($inbuf eq "end")) {
                print "$inbuf\n";
                $inbuf = <$socket>;
                chomp($inbuf);
            }
	
            print "\n";
        }
    } else {
        print "Error: $inbuf\n";
    }
    return $user;
}

#
# General purpose function to add a reservation.
# Used by both agent and customer functions.
#
sub add_reservation(@) {

    my $type = shift;
    my $outstream;
    my $cust_name;
    my $flight_entry;
    my $num_seats;

    #
    # Decide which username to pass to
    # server
    #
    if ($type =~ /2/) {
        #if agent, request customer username  
        print "Enter customer username: ";
        $cust_name = <STDIN>; 
    } else {
        #if customer, send customer username stored in global
	$cust_name = "$login_name\n";
    }
    
    chomp($cust_name);

    #
    # Select a specific flight entry
    #
    print "Enter flight entry #: ";
    $flight_entry = <STDIN>; 
    chomp($flight_entry);

    #
    # Specify number of desired seats
    #
    print "Number of seats: ";
    $num_seats = <STDIN>;

    #
    # Send data to server
    # 
    $outstream = "$cust_name:$flight_entry:$num_seats";
    print $socket $outstream;

    $inbuf = <$socket>;
    chomp($inbuf);

    if ($inbuf eq "ACK") {
        print "Successfully added reservation!\n";
    } else {
	print "Server Error: $inbuf\n";
    }
 
}

#
# General purpose used to view flights.
# Used by admin, agent and customer
#
sub view_flights(@) {
        my $type = shift;
        #
	# List all flights for particular airline
	#     -send login name/airline for sql query
	#
        
	#
	# Handle specific cases for admin/agent/cust.
	#
        if (($type == 2) || ($type == 4)) {
            print $socket "$login_name:$agent_airline\n";
        } else {
            print $socket "$login_name\n";
	}

        $inbuf = <$socket>;
	chomp($inbuf);

	#
	# If data is valid
	#
        if ($inbuf eq "ACK") {
            if ($type < 4) {
		#
		# Receive and display data
		#
    	        print "\n ---List of Flights---\n";
	        $inbuf = <$socket>;	
	        chomp($inbuf);
	        while (!($inbuf eq "end")) {
	            print "$inbuf\n";
	            $inbuf = <$socket>;
	            chomp($inbuf);
	        }
	
	        print "\n";
	    }
	} else {
	    print "Server Error: $inbuf\n";
        }
}

#
# Manages intial customer functions
# before main customer function is called
#
sub initialClient() {

    my $c_flag = 1;
    while ($c_flag) {
        #
    	# Initial Menu
    	#
        print "-----------------------------------\n";
    	print " Customer Menu\n\n";
    	print "    Select option [1-3]:\n";
    	print "    1) Login \n";
    	print "    2) Create new user \n";
    	print "    3) Exit \n";
        print "-----------------------------------\n";

   	print "Option: ";
	$outbuf = <STDIN>;

	if (validate($outbuf)) {

  	    SWITCH: {
		#
		# call main function to manage client
		#
		$outbuf =~ /1/ && do {
		    manageClient();
		    last SWITCH;
		};

		#
		# create new user
		#
		$outbuf =~ /2/ && do {
		    user_creation(3);
		    last SWITCH;
		};

		#
		# exit
		#
		$outbuf =~ /3/ && do {
		    $c_flag = 0;
		    last SWITCH;
		};
 	    }
	}
    }
}

#
# Main function to handle all client activities
#
sub manageClient() {
    my $c_flag = user_login(3);
    
    while ($c_flag) {
        #
    	# Menu
    	#
        print "-----------------------------------\n";
    	print " Customer Menu\n\n";
    	print "    Select option [1-5]:\n";
    	print "    1) View all flights \n";
    	print "    2) View existing reservations \n";
    	print "    3) Add reservation \n";
    	print "    4) Delete reservation \n";
    	print "    5) Exit \n";
        print "-----------------------------------\n";

   	print "Option: ";
	$outbuf = <STDIN>;

        if (validate($outbuf)) {
	    my $user;
	    SWITCH: {
		#
		# view all flights
		#
		$outbuf =~ /1/ && do {
		    view_flights(3);
		    last SWITCH;
		};

		#
		# view customer reservations
		#
		$outbuf =~ /2/ && do {
		    $user = view_reservations(3,0);
		    last SWITCH;
		};

		#
		# add a customer reservation
		#
		$outbuf =~ /3/ && do {
		    view_flights(3);
		    add_reservation(3);
		    last SWITCH;
		};

		#
		# delete a customer reservation
		#
		$outbuf =~ /4/ && do {
		    view_flights(5);
	     	    $user = view_reservations(3,0);
		    delete_reservation($user);
		    last SWITCH;
		};

		#
		#
		#
		$outbuf =~ /5/ && do {
		    $c_flag = 0;
		    last SWITCH;
		};
	    }
        }
    }
}

#
# add a flight function used by admin
#
sub add_flight() {

    my $airline;
    my $flight_num;
    my $num_seats;
    my $terminal;
    my $dpt_city;
    my $arr_city;
    my $dpt_time;
    my $arr_time;
    my $flight_date;
    
    #
    # Aask for all relevant airline information
    #
    print "Airline Name: ";
    $airline = <STDIN>;
    chomp($airline);

    print "Flight number: ";
    $flight_num = <STDIN>;
    chomp($flight_num);

    print "Number of seats: ";
    $num_seats = <STDIN>;
    chomp($num_seats);

    print "Terminal: ";
    $terminal = <STDIN>;
    chomp($terminal);

    print "Departure city: ";
    $dpt_city = <STDIN>;
    chomp($dpt_city);

    print "Arrival city: ";
    $arr_city = <STDIN>;
    chomp($arr_city);

    print "Departure time [24-hr format hhmm]: ";
    $dpt_time = <STDIN>;
    chomp ($dpt_time);

    print "Arrival time [24-hr format hhmm]: ";
    $arr_time = <STDIN>;
    chomp($arr_time);

    print "Date of flight [YYYYMMDD]: ";
    $flight_date = <STDIN>;

    #
    # Send to server for processing
    #
    $outstream = "$airline:$flight_num:$num_seats:$terminal:$dpt_city:$arr_city:$dpt_time:$arr_time:$flight_date";
    print $socket $outstream;
    
    $inbuf = <$socket>;
    chomp($inbuf);
    if ($inbuf eq "ACK") {
        print "Successfully added new flight!\n";
    } else {
        print "Server error: $inbuf\n";
    }

}
#################################
#
# function validate()
#
# purpose:
#     this function is used to 
#     validate menu options passed
#     from the admin, customer, and
#     travel agent menus
#
# usage:
#    validate(<data>)
#
# returns:
#    1: success
#    0: failure
#################################
sub validate(@) {

    my $data = shift;
   
    #
    # send data to server
    # 
    print $socket $data;
    $inbuf = <$socket>; 
    chomp($inbuf);

    if ($inbuf =~ /ACK/) {
        return 1; 
    }
    
    print "Server Error: $inbuf\n"; 
    return 0; #Error 
    
}

sub handler() {
    my ($signo) = shift;

    if ($signo eq "INT" || $signo eq "QUIT")
    {
#  Send the quit packet on a terminal interrupt!
         print $socket "QUIT\n"; 
         close($socket);
         exit(1);
    }
    else  ############  SIGPIPE!!
    {
         print "Server died\n";
         exit(2);
    }
}
