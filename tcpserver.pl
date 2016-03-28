#!/usr/bin/perl 
#
# CMPE 207 Project - Distributed Airline System
# Server Code
# Spring 2012
#
#
###############################  TCPServer  ###########################

use strict;
use IO::Socket;      
#use IO::Socket::SSL;      
use POSIX qw(sys_wait_h);
use DBI;

my $port;

if ($#ARGV == 0) {
    $port = $ARGV[0];
} else {
    $port = 3689;
}

#
# set up socket -> can instead use IO::Socket::SSL for encryption
#
my $socket = IO::Socket::INET->new(LocalPort => $port,
                                Type      => SOCK_STREAM,
                                Reuse     => 1,
                                Listen    => 10)
             or
die "Could not open socket!\n";

#  Trap writes to non-existent clients.
$SIG{PIPE} = 'handler'; 

#  Timeout slow clients.
$SIG{ALRM} = 'handler';

#  Kill zombie children!
#$SIG{CHLD} = 'reaper';  
$SIG{CHLD} = 'IGNORE';  

#
# Set up DB object; searches for db in current dir
#
my $db = DBI->connect("DBI:CSV:f_dir=.") || die "Cannot connect: $DB::errstr\n";

#
# Can hardcode admin credentials
# because there should be only 1 
# system admin
#
my $admin_name = "admin";
my $admin_password = "admin12345";

my $buffer;
my $client;
my $pid;
my $entries = 0;

#  Server lives forever!
while(1)     
{
      $client = $socket->accept() or die "No active socket!\n";

#  Fork child process to handle client requests.  Parent process just goes
#  back up and awaits new clients.
      die "Bad fork!\n" if (!defined($pid = fork()));

      if ($pid == 0)   #  Child process! 
      {
            close($socket);   # Child not listening for clients on $socket!! 
	    my $quit_flag = 1;
    
	    while ($quit_flag) {
	        #
	        # receive initial menu option from client
                #
                $buffer = <$client>;
                chomp($buffer);
    	
	        #
	        # verify menu input is within proper
                # range and call appropriate function
	        # to handle option
                #
                if (validate($buffer,1,4)) {
                    if ($buffer =~ /1/) {
                        manageAdmin();
                    } elsif ($buffer =~ /2/) {
                        manageAgent();
                    } elsif ($buffer =~ /3/) {
                        initialClient();
                    } else {
	    	        $quit_flag = 0;
                    }
                } 
            }
            close($client);
            exit(0);  #  Vital or child process creates grandchildren!! 
      }
      else   #  Parent process! 
      {
           close($client);   # Parent not transferring data over active socket. 
      } 
}

##############################
#
# function validate()
#
# purpose:
#    this function acts a generic
#    function to validate menu options
#    received from the client
# usage:
#    validate(<menu option>, <start number>, <end number>)
#
# returns:
#    1: success (correct menu option)
#    0: failure (incorrect menu option)
###############################
sub validate(@) {
    my $data = shift;
    my $num1 = shift;
    my $num2 = shift;

    #
    # check for numbers only
    #
    if ($data =~ /^\s*[$num1-$num2]\s*$/) {
        print $client "ACK\n";
        return 1;
    } else {
        print $client "Invalid input '$data'\n";
        return 0;
    } 

}

#
# Handle admin
#
sub manageAdmin() {

    my $c_flag = user_login(1);
    my $rows;

    #
    # Loop until user is done with menu options
    #
    while ($c_flag) { 
        #
        # Receive option 1-7 from admin menu
        #
        $buffer = <$client>;
        chomp ($buffer);
    
        if (validate($buffer, 1, 7)) {
        
            SWITCH:
            {
 	        # 
	        # View all flights
	        #
                $buffer =~ /1/ && do 
                {
		    $rows = view_flights(1);
  	            last SWITCH;
                };    
      
	        #
  	   	# View all reservations
		# 
                $buffer =~ /2/ && do 
                {
		    view_reservations(1,1);
  	            last SWITCH;
                };    
       
                #
                # Add flight 
	        # 
                $buffer =~ /3/ && do 
                {
     	            add_flight();
  	            last SWITCH;
                };    

	        #
  	        # Modify flight
	        #
                $buffer =~ /4/ && do 
                {
  		    $rows = view_flights(1);
		    modify_flight();
  	            last SWITCH;
                };    
        
	        #
	        # Delete flight
	        #
                $buffer =~ /5/ && do 
                {
	            $rows = view_flights(5);
		    delete_flight();
  	            last SWITCH;
                };    
        
  	        #
 	        # Add agent
	        #
                $buffer =~ /6/ && do 
                {
		    user_creation(2);
  	            last SWITCH;
                };    
		
		#
		# Exit
		#
                $buffer =~ /7/ && do 
                {
  	            $c_flag = 0;
  	            last SWITCH;
                };    
            }
        } 
    }    
}

#
# This function modifies the individual fields of
# a selected flight using the reservation id
#
sub modify_flight() {
    my $entry; 
    my $value;
    my $field;
    my $update_db;
 
    #
    # Receive flight id
    #
    $entry = <$client>;
    chomp($entry);

    #
    #receive menu option
    #    
    $buffer = <$client>;
    chomp($buffer);

    #
    # Set db field to change according to option
    #
    if (validate($buffer,1,9)) {
        $value = <$client>;
        chomp($value);

        SWITCH: {
	    $buffer =~ /1/ && do {
		$field = "airline";
		last SWITCH;
	    };

	    $buffer =~ /2/ && do {
		$field = "flightnum";
		last SWITCH;
	    };

	    $buffer =~ /3/ && do {
		$field = "numseats";
		last SWITCH;
	    };

	    $buffer =~ /4/ && do {
		$field = "terminal";
		last SWITCH;
	    };

	    $buffer =~ /5/ && do {
		$field = "dptcity";
		last SWITCH;
	    };

	    $buffer =~ /6/ && do {
		$field = "arrcity";
		last SWITCH;
	    };

	    $buffer =~ /7/ && do {
		$field = "dpttime";
		last SWITCH;
	    };

	    $buffer =~ /8/ && do {
		$field = "arrtime";
		last SWITCH;
	    };

	    $buffer =~ /9/ && do {
		$field = "date";
		last SWITCH;
	    };
	}

        #
        # Update 'flights' db using selected field and value 
        #
        $update_db = $db->prepare("UPDATE flights SET $field='$value' WHERE entry='$entry'");
        if (!$update_db->execute()) {
            print $client "Error updating flight db\n";
            return 0;
        }

        #
        # Send client ack to show that update
        # was successful
        #
        print $client "ACK\n";
    }
}

#
# admin function to delete an existing flight
#
sub delete_flight() {
    my $delete_entry;
    my $flight_id;
    my $check_entry;
    my $rows;

    #
    # receive desired entry to delete from client
    #
    $flight_id = <$client>;
    chomp($flight_id);

    #
    #  Make sure flight entry exists before proceeding
    #
    $check_entry = $db->prepare("SELECT * FROM flights WHERE entry='$flight_id'");

    if (!$check_entry->execute()) {
        print $client "Could not execute flight search\n";
        return 0;
    }

    $rows = $check_entry->fetchall_arrayref();
    if (!@$rows) {
 	print $client "Invalid flight id: '$flight_id'\n";
	return 0;
    }

    #
    # Delete entry from flights table
    #
    $delete_entry = $db->prepare ("DELETE FROM flights WHERE entry='$flight_id'");

    if (!$delete_entry->execute()) {
        print $client "Could not delete flight from flight list\n";
        return 0;
    } 

    
    $delete_entry = $db->prepare ("DELETE FROM reservations WHERE flight='$flight_id'");
    
    if (!$delete_entry->execute()) {
        print $client "Could not delete from reservation list\n";
    }
    
    #
    # send ack to client if successful
    #
    print $client "ACK\n";

}

#
# Handle agent
#
sub manageAgent() {
    my $c_flag = user_login(2);
    while ($c_flag) { 

        my $rows;
        
        #
        # receive agent menu option
        #
        $buffer = <$client>;
        chomp ($buffer);
	
	#
        # validate menu option
        #
        if (validate($buffer,1,5)) {
            SWITCH:
	    {
		#
		# view flights of agent's users
		#
		$buffer =~ /1/ && do {
	 	    $rows = view_flights(2);
		    last SWITCH;
		};
		
		#
		# add a reservation to airline
		#
		$buffer =~ /2/ && do {
	 	    $rows = view_flights(2);
		    add_reservation($rows);
		    last SWITCH;
		};
		
		#
		# view existing reservations under airline
		#
		$buffer =~ /3/ && do {
	 	    view_reservations(2,1);
		    last SWITCH;
		};
		
		#
		# delete an existing reservation of airline
		#
		$buffer =~ /4/ && do {
  		    $rows = view_flights(4);
 		    view_reservations(2,0);
		    delete_reservation($rows);
		    last SWITCH;
		};
		
		#
		# exit
		#
		$buffer =~ /5/ && do {
	 	    $c_flag = 0;
		    last SWITCH;
		};
	    }
        }
    }
}

#
# General purpose function to delete
# reservations. This function can be used
# for airline agent and customer purposes
#
sub delete_reservation(@){
    my $rows = shift;
    my $row;
    my $rows2;
    my $row2;
    my $entry;
    my $seats;
    my $user;
    my $get_seats;
    my $delete_row;
    my $avail_seats;
    my $update_db;

    #
    # find out customer name and 
    # desired reservation id to remove
    #
    $buffer = <$client>;
    chomp($buffer);

    ($user, $entry) = split (":", $buffer);
  
    #
    # query for table entry that contains # of seats
    # 
    $get_seats = $db->prepare("SELECT * FROM reservations WHERE flight='$entry' AND username='$user'");

    if (!$get_seats->execute()) {
        print $client "Could not locate reservation\n";
        return 0;
    }

    $rows2 = $get_seats->fetchall_arrayref();

    if (!@$rows2) {
        print $client "Could not locate number of seats\n";
        return 0;
    }

    #
    # Once # seats located, store it
    #
    foreach $row2 (@$rows2) {
        $seats = $row2->[2];
    }
    
    #
    # delete reservation from table
    #
    $delete_row = $db->prepare ("DELETE FROM reservations WHERE username='$user' AND flight='$entry'");

    if (!$delete_row->execute()) {
        print $client "Could not delete reservation\n";
        return 0;
    } 

    #######################################
    # update seats entry in flights table
    #######################################
    
    #
    # Retrieve number of seats
    #
    $avail_seats = -1;
    foreach $row (@$rows) {
        if ($row->[0] == $entry) {
            $avail_seats = $row->[3];
	}
    }

    if ($avail_seats == -1) {
        print $client "Invalid flight entry #\n";
        return 0;
    }
   
    #
    # Compute how many seats are available
    # after deletion
    # 
    $avail_seats = $avail_seats + $seats; 
    
    #
    # Update 'flights' db 
    #
    $update_db = $db->prepare("UPDATE flights SET numseats='$avail_seats' WHERE entry='$entry'");
    if (!$update_db->execute()) {
        print $client "Error updating flight db\n";
        return 0;
    }

    #
    # send ack to client
    #
    print $client "ACK\n";
}

#
# A general purpose function used by
# all functions (admin, agent, customer)
# to view existing reservations
#
sub view_reservations(@) {

    my $type = shift;
    my $displayAll = shift;
    my $username;
    my $airline;
    my $db_name = "reservations";
    my $list_reservations;
    my $rows;
    my $row;

    #
    # receive login name/airline for sql query
    #
    $buffer = <$client>;
    chomp($buffer);

    ($airline, $username) = split(":", $buffer);

    #
    # Handle special cases for admin, agent and customer
    # and display all reservations if desired
    #    
    if ($displayAll) {
        if ($type == 2) {
            $list_reservations = $db->prepare("SELECT * FROM $db_name WHERE airline='$airline'");
        } else {
            $list_reservations = $db->prepare("SELECT * FROM $db_name");
        }
    } else {
        if ($type == 2) {
            $list_reservations = $db->prepare("SELECT * FROM $db_name WHERE username='$username' AND airline='$airline'");
        } else {
            $list_reservations = $db->prepare("SELECT * FROM $db_name WHERE username='$username'");
        }
    }

    if (!$list_reservations->execute()) {
        print $client "DB error. Could not search db for flights\n";
        return 0;
    }
    
    $rows = $list_reservations->fetchall_arrayref();

    if (!@$rows) {
        print $client "No flights found\n";
        return 0;
    } else {
        print $client "ACK\n";
    }


    # 
    # Send reservation data to client after formatting data
    #    
    if ($type < 4) {    
        printf $client ( "|%-10s|%-15s|%-10s|\n", "Customer", "Reservation #", "Seats");
        foreach $row (@$rows) {
            printf $client ( "|%-10s|%-15s|%-10s|\n", "$row->[0]", "$row->[1]", "$row->[2]");
	    
        }
        print $client "end\n";
    }
  
}

#
# General purpose function used by agent/customer functions
# to create new reservations
#
sub add_reservation(@) {
    my $rows = shift;
    my $db_name = "reservations";
    my $create; # db obj
    my $username;
    my $flight;
    my $seats;
    my $avail_seats;
    my $row_insert;
    my $row;
    my $update_db;
    my $airline;

    #
    # receive information about username and flight
    # to book reservation for
    # 
    $buffer = <$client>;
    chomp($buffer);
    
    #
    # Create database if it doesn't exist
    #
    if (! -e $db_name) { 
        $create = $db->prepare ("CREATE TABLE $db_name (
				username varchar(32) not null,
				flight varchar(32) not null,
				seats varchar(32) not null,
				airline varchar(32) not null)");

        #
        # exit if db could not be initialized
        #
	if (!$create->execute()) {
            print $client "Could not create $db_name database\n";
    	    return 0;
        }
    }
     
    #
    # Parse from buffer
    #
    ($username, $flight, $seats) = split(":",$buffer);

    #
    # Retrieve number of seats
    #
    $avail_seats = -1;
    foreach $row (@$rows) {
        if ($row->[0] == $flight) {
            $avail_seats = $row->[3];
	    $airline = $row->[1];
	}
    }

    if ($avail_seats == -1) {
        print $client "Invalid flight entry #\n";
        return 0;
    }

    #
    # Check there are enough seats for reservation 
    #
    if ($avail_seats < $seats ) {
        print $client "Plane does not have enough capacity for reservation\n";
        return 0;
    } else {
        $avail_seats = $avail_seats - $seats;
    }

    #
    # Insert reservation into db
    #
    $row_insert = $db->prepare("INSERT INTO $db_name (username, flight, seats, airline)
 					VALUES ('$username', '$flight', '$seats', '$airline')");
    if (!$row_insert->execute()) {
        print $client "Error adding reservation to database\n";
        return 0;
    } 

    #
    # Update 'flights' db 
    #
    $update_db = $db->prepare("UPDATE flights SET numseats='$avail_seats' WHERE entry='$flight'");
    if (!$update_db->execute()) {
        print $client "Error updating flight db\n";
        return 0;
    }
     
    #
    # Successful
    #
    print $client "ACK\n";

}

#
# General purpose function to view all flights
# with special cases for admin, agent and cust.
#
sub view_flights(@) {

    my $type = shift;
    my $username;
    my $airline;
    my $list_flights;
    my $db_name = "flights";
    my $rows;
    my $row;

    #
    # receive login name/airline for sql query
    #
    $buffer = <$client>;
    chomp($buffer);

    #
    # Handle different receive cases
    #
    if (($type == 2) || ($type == 4)) {
        ($username, $airline) = split (":",$buffer);
    } else {
	$username = $buffer;
    }
    
    #
    # Handle different sql queries
    #
    if (($type == 2) || ($type == 4)) {
        $list_flights = $db->prepare("SELECT * FROM $db_name WHERE airline='$airline'");
    } else {
        $list_flights = $db->prepare("SELECT * FROM $db_name");
    }

    if (!$list_flights->execute()) {
        print $client "DB error. Could not search db for flights\n";
	return 0;
    }
    
    $rows = $list_flights->fetchall_arrayref();

    if (!@$rows) {
        print $client "No flights found\n";
	return 0;
    }

    print $client "ACK\n";
    
    #
    # Format data and send back to client to show to user
    #
    if ($type < 4) {    
        printf $client ( "|%-10s|%-15s|%-10s|%-10s|%-10s|%-10s|%-10s|%-10s|%-10s|%-10s|\n", "Entry", "Airline", "Flight #", "Seats", "Terminal", "D. City", "A. City", "D. Time", "A. Time", "Date");

        $entries = 0;
        foreach $row (@$rows) {
            $entries++;
            printf $client ( "|%-10s|%-15s|%-10s|%-10s|%-10s|%-10s|%-10s|%-10s|%-10s|%-10s|\n", "$row->[0]", "$row->[1]", "$row->[2]", "$row->[3]", "$row->[4]", "$row->[5]", "$row->[6]", "$row->[7]", "$row->[8]", "$row->[9]");
	    
        }
        print $client "end\n";
    }
  
    return $rows;

}

####################################
#
# function user_login()
#
# purpose:
#    this function handles all
#    user login authentication for
#    customers, admin, and airline
#    agent
#
# usage:
#    user_login(<user type>)
#        <1>: admin
#        <2>: airline agent
#        <3>: customer
#
####################################
sub user_login(@) {
  
    my $user_type = shift;
    my $username;
    my $password;
    my $query_pass;
    my $query_user;
    my $query_airline;
    my $auth_check;
    my $db_name;
    my $rows="";
    my $not_null = 0;

    SWITCH: 
    {
        #
 	# admin
	#
        $user_type =~ /1/ && do
	{
            $username = $admin_name;
	    $password = $admin_password;
     	    last SWITCH;
	};

	#
	# airline agent
	#
        $user_type =~ /2/ && do
	{
	    $username = "null";
            $password = "null";
            $db_name = "agent_users";
     	    last SWITCH;
	};
	
	#
	# customer
	#
        $user_type =~ /3/ && do
	{
	    $username = "null";
            $password = "null";
            $db_name = "customer_users";
     	    last SWITCH;
	};


    }
    
    #
    # receive user login info
    # from client stream
    #
    $buffer = <$client>;
    chomp($buffer);
    
    #
    # Parse login data and check with db.
    # Also handles special cases for admin
    # agent and customer
    #
    if ($user_type =~ /2/) {
        ($query_user, $query_pass, $query_airline) = split (":", $buffer);
        $auth_check = $db->prepare("SELECT * FROM $db_name WHERE username = '$query_user' AND password = '$query_pass' AND airline = '$query_airline'");    

        if (!$auth_check->execute()) {
            print $client "Error checking for username\n";
            return 0;
         }
        $rows = $auth_check->fetchall_arrayref();
        if (@$rows > 0) {
            $not_null = 1;
        }
    } elsif ($user_type =~ /3/) {
        ($query_user, $query_pass) = split (":", $buffer);
        $auth_check = $db->prepare("SELECT * FROM $db_name WHERE username = '$query_user' AND password = '$query_pass'");    

        if (!$auth_check->execute()) {
            print $client "Error checking for username\n";
            return 0;
         }
        $rows = $auth_check->fetchall_arrayref();
        if (@$rows > 0) {
            $not_null = 1;
        }
    }
    
    #
    # compare with database values
    #
    if (($buffer eq "$username:$password") || $not_null) {
        print $client "ACK\n";
        return 1;
    } else {
        print $client "Invalid user credentials\n";
        return 0;
    }
}

#
# General purpose function to create
# a new user.
# Can be used to create new agents and customer
# accounts.
# 
sub user_creation(@) {
  
    my $user_type = shift;
    my $username;
    my $password;
    my $db_name;
    my $create; # db object
    my $dup_check; #db object
    my $row_insert; #db object
    my $rows; # used to read in rows of db
    my $airline;
    my $fname;
    my $lname;

    SWITCH: 
    {
        #
 	# admin
   	#     this code should never be called
	#
        $user_type =~ /1/ && do
	{
     	    last SWITCH;
	};

	#
	# airline agent
	#
        $user_type =~ /2/ && do
	{
	    $db_name = "agent_users";
     	    last SWITCH;
	};
	
	#
	# customer
	#
        $user_type =~ /3/ && do
	{
 	    $db_name = "customer_users";
     	    last SWITCH;
	};

    }
    
    #
    # Create database if it doesn't exist
    #
    if (! -e $db_name) { 
        if ($user_type =~ /2/) {
            $create = $db->prepare ("CREATE TABLE $db_name (
	    				username varchar(32) not null,
					password varchar(32) not null,
					fname varchar(32) not null,
					lname varchar(32) not null,
 					airline varchar(32) not null)");
        } else {
            $create = $db->prepare ("CREATE TABLE $db_name (
					username varchar(32) not null,
					password varchar(32) not null,
					fname varchar(32) not null,
					lname varchar(32) not null)");
        }

        #
        # exit if db could not be initialized
        #
	if (!$create->execute()) {
            print $client "Could not create $db_name database\n";
    	    return 0;
        }
    }
     
    $buffer = <$client>;
    chomp($buffer);

    #
    # Parse username/password from buffer
    #
    if ($user_type =~ /2/) {
        ($username, $password, $fname, $lname, $airline) = split(":",$buffer);
    } else {
        ($username, $password, $fname, $lname) = split(":",$buffer);
    }

    #
    # check username/password are in correct format
    #
    if ($username !~ /^(\d*|\w*)+$/) {
        print $client "Invalid username format $username\n";
        return 0;
    }
    if ($password !~ /^(\d*|\w*)+$/) {
        print $client "Invalid password format\n";
        return 0;
    }

    #
    # Check for existence of user
    # (no duplicates)
    #
    if ($user_type =~ /2/) {
        $dup_check = $db->prepare("SELECT * FROM $db_name WHERE username = '$username' AND airline='$airline'");    
    } else {
        $dup_check = $db->prepare("SELECT * FROM $db_name WHERE username = '$username'");    
    }

    if (!$dup_check->execute()) {
        print $client "Error checking for duplicate username\n";
        return 0;
     }
    
    $rows = $dup_check->fetchall_arrayref();

    # 
    # If array is not null
    # duplicate is found
    #
    if (@$rows) {
        print $client "Username '$username' already exists!\n";
        return 0;
    }

    #
    # Insert username/password into db
    #
    if ($user_type =~ /2/) {
        $row_insert = $db->prepare("INSERT INTO $db_name (username, password, fname, lname, airline)
 					VALUES ('$username', '$password', '$fname', '$lname', '$airline')");
    } else {    
        $row_insert = $db->prepare("INSERT INTO $db_name (username, password, fname, lname)
 					VALUES ('$username', '$password', '$fname', '$lname')");
    }
    if (!$row_insert->execute()) {
        print $client "Error adding username and password to database\n";
        return 0;
    } 
    #
    # If code is here, that means
    # user was added to database
    #
    print $client "ACK\n"; 
    return 1;

}

#
# Function that handles initial
# menu items for the customer
#
sub initialClient() {
    my $c_flag = 1;
    while ($c_flag) {
	$buffer = <$client>;
	chomp($buffer);

	#
	# Check menu option is valid
	#
	if (validate($buffer,1,3)) {
	    SWITCH: {
		#
		# Login
		#
		$buffer =~ /1/ && do {
		    manageClient();
		    last SWITCH;
		};

		#
		# Create new user
		#
		$buffer =~ /2/ && do {
		    user_creation(3);
		    last SWITCH;
		};

		#
		# Exit
		#
		$buffer =~ /3/ && do {
		    $c_flag = 0;
		    last SWITCH;
		};
	    }
	}
    }
}

#
# Main client function
#
sub manageClient() {
    my $c_flag = user_login(3);
    my $rows;

    while ($c_flag) {
	$buffer = <$client>;
  	chomp($buffer);
	
	#
	# Check menu option is valid
	#
	if (validate($buffer,1,5)) {
	    SWITCH: {

		#
		# view flights
		#
		$buffer =~ /1/ && do {
		    $rows = view_flights(3);
		    last SWITCH;
		};

		#
		# view reservations
		#
		$buffer =~ /2/ && do {
		    view_reservations(3,0);
		    last SWITCH;
		};

		#
		# add a reservation
		#
		$buffer =~ /3/ && do {
		    $rows = view_flights(3); 
		    add_reservation($rows);
		    last SWITCH;
		};

		#
		# delete a reservation
		#
		$buffer =~ /4/ && do {
  		    $rows = view_flights(5);
 		    view_reservations(3,0);
		    delete_reservation($rows);
		    last SWITCH;
		};

		#
		# exit
		#
		$buffer =~ /5/ && do {
		    $c_flag = 0;
		    last SWITCH;
		};
	    }
	}
    }
}

#
# Admin function used to add
# new flights
#
sub add_flight() {
   
    #
    # Array for storing flight info
    # [0] entry 
    # [1] airline
    # [2] flight number
    # [3] number of seats
    # [4] terminal
    # [5] departure city
    # [6] arrival city
    # [7] departure time
    # [8] arrival time
    # [9] date of flight
    # 
    my @flight_info;
    my $db_name = "flights";    
    my $create;
    my $entry;
    my $rows;
    my $row_insert;
    my $row_count;
    my $dup_check;

    #
    # Receive flight info from client
    #
    $buffer = <$client>;
    chomp($buffer);
    @flight_info = split (":",$buffer);

    if (! -e $db_name) {

	#
	# Create table if it does not exist
	#
        $create = $db->prepare ("CREATE TABLE $db_name (
				entry varchar(32) not null,
				airline varchar(32) not null,
				flightnum varchar(32) not null,
				numseats varchar(32) not null,
				terminal varchar(32) not null,
				dptcity varchar(32) not null,
				arrcity varchar(32) not null,
				dpttime varchar(32) not null,
				arrtime varchar(32) not null,
 				date varchar(32) not null)");
    

        if (!$create->execute()) {
            print $client "Error creating flight db\n";
            return 0;
        }
    } 

    #
    # Count number of rows in table
    #
    $row_count = $db->prepare ("SELECT COUNT(*) FROM $db_name");
    $row_count->execute();

    $entry = $row_count + 1; #increment for new entry

    #
    # Check for existence of flight 
    # (no duplicates)
    #
    $dup_check = $db->prepare("SELECT * FROM $db_name WHERE airline = '$flight_info[0]'
				AND flightnum='$flight_info[1]'
				AND dpttime='$flight_info[6]'
   				AND date='$flight_info[8]'");    

    if (!$dup_check->execute()) {
        print $client "Error checking for duplicate flight\n";
        return 0;
     }
    
    $rows = $dup_check->fetchall_arrayref();

    # 
    # If array is not null
    # duplicate is found
    #
    if (@$rows) {
        print $client "Flight already exists!\n";
        return 0;
    }

    #
    # Insert flight into db
    #
    $row_insert = $db->prepare("INSERT INTO $db_name (entry, airline, flightnum, numseats, terminal, dptcity, arrcity, dpttime, arrtime, date)
				VALUES ('$entry', '$flight_info[0]', '$flight_info[1]', '$flight_info[2]', '$flight_info[3]', '$flight_info[4]',
					'$flight_info[5]', '$flight_info[6]', '$flight_info[7]', '$flight_info[8]')");
    if (!$row_insert->execute()) {
        print $client "DB Error. Could not insert flight information.\n";
        return 0;
    }

    #
    # If code is here, successful
    #
    print $client "ACK\n";
    return 1;
   
}

#  Get rid of zombies.
sub reaper
{
     my $kidpid;
     while (($kidpid = waitpid(-1,WNOHANG)) > 0) {print "Reaped $kidpid\n"}
     close($client);
}
sub handler
{
    my ($signo) = shift;

    close($client);  #  Give socket descriptor back to the system. 
    print "Signal was $signo!\n";
    exit(1);
}
