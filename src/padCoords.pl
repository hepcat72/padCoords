#!/usr/bin/perl -w

#A simple script to take a column of start coordinates and a column of stop coordinates and a parameter indicating a padding length P.  Output is the same format, but with P subtracted from the lesser coordinate and P added to the greater coordinate.  Chromosome is assumed to be linear and that the last coordinate is more than P from the end.
#Usage: padChrCoords.pl 10 < input_file.txt > output_file.txt

#Example Input file:
#chr1 40   90   comment...
#chr1 110  165  comment...

#Example Output file:
#chr1 30   100  comment...
#chr1 100  175  comment...

use CommandLineInterface;

setScriptInfo(VERSION => '2.0',
              CREATED => 'circa 2010',
              AUTHOR  => 'Robert William Leach',
              CONTACT => 'rleach@princeton.edu',
              COMPANY => 'Princeton University',
              LICENSE => 'Copyright 2018',
              HELP    => ('This script pads a pair of coordinates by a ' .
			  'given ammount, e.g. padding coordinates 200,300 ' .
			  'by 100 would change the coordinates to 100,400.  ' .
			  'Order of the coordinates is unimportant, e.g. ' .
			  'padding 300,200 by 100 would yield 400,100.'));

setDefaults(HEADER        => 0,
	    ERRLIMIT      => 3,
	    COLLISIONMODE => 'error', #,merge,rename (when outfile conflict)
	    DEFRUNMODE    => 'usage',
	    DEFSDIR       => undef);

my $iid = addInfileOption(GETOPTKEY   => 'i|infile=s',
			  REQUIRED    => 1,
			  PRIMARY     => 1,
			  FLAGLESS    => 1,
			  SMRY_DESC   => 'Tab delimited file.',
			  FORMAT_DESC => ('Tab delimited input text file, ' .
					  'containing a column of start ' .
					  'coordinates and a column of stop ' .
					  'coordinates.  Order of the ' .
					  'coordinates in these columns is ' .
					  'unimportant.  Coordinates will ' .
					  'always be expanded outward.'));

my($s);
addOption(GETOPTKEY   => 's|size|pad=i',
	  GETOPTVAL   => \$s,
	  REQUIRED    => 1,
	  SMRY_DESC   => 'Pad ammount.',
	  DETAIL_DESC => ('Pad ammount.  This value will be subtracted from ' .
			  'the lesser coordinate and added to the greater ' .
			  'coordinate (whichever coordinate column they are ' .
			  'in).'));

my($startcol,$stopcol);
my $coordcols = [];
addArrayOption(GETOPTKEY   => 'c|c1|c2|coord-columns|start-col|stop-col=s',
	       GETOPTVAL   => $coordcols,
	       DEFAULT     => 'auto*',
	       REQUIRED    => 0,
	       SMRY_DESC   => ('Column numbers of coordinate columns.  ' .
			       'Supply twice.  * See --extended usage.'),
	       DETAIL_DESC => ('Column numbers of coordinate columns.  ' .
			       'Either supply twice (once for each ' .
			       'coordinate column) or supply the 2 values ' .
			       'is a single space-delimited string ' .
			       'surrounded by quotes.  If the same column ' .
			       'is selected for both start and stop ' .
			       'coordinates, a column will be appended at ' .
			       'the end of the line to hold the larger ' .
			       'output value.  The other will be changed in ' .
			       'place.\n\n' .
			       '* Defaults to the first & second columns if ' .
			       'there are only 2 columns, or the second & ' .
			       'third column if there are only 3 columns.  ' .
			       'If there is 1 column, it defaults to that ' .
			       'one column for both.  Required if there are ' .
			       'more than 3 columns.'));

my $ttid = addOutfileTagteamOption(GETOPTKEY_SUFF   => 'o|outfile-suffix=s',
				   GETOPTKEY_FILE   => 'outfile=s',
				   FILETYPEID       => $iid,
				   PRIMARY          => 1,
				   DETAIL_DESC_SUFF => ('Extension appended ' .
							'to file submitted ' .
							'via -i.'),
				   DETAIL_DESC_FILE => 'Outfile.',
				   FORMAT_DESC      => << 'end_format'

Tab delimited text.  Note, carriage returns will be changed to newline characters.

end_format
				  );

processCommandLine();

if($s < 0)
  {
    error("Invalid pad size (-s): [$s]");
    usage(1);
    quit(1);
  }

if(scalar(@$coordcols))
  {
    if(scalar(@$coordcols) == 2)
      {($startcol,$stopcol) = @$coordcols}
    elsif(scalar(@$coordcols) == 1)
      {$startcol = $coordcols->[0]}
    else
      {
	error("Too many coordinate columns supplied to -c.  These column ",
	      "numbers will be ignored: [",
	      join(',',@{$coordcols}[2..$#{$coordcols}]),"].");
	($startcol,$stopcol) = @{$coordcols}[0,1];
      }
  }

if(defined($startcol))
  {
    if($startcol =~ /\D/ || $startcol eq '')
      {
	error("Invalid column 1 (-c): [$startcol]");
	usage(1);
	quit(2);
      }
    else
      {$startcol--}
  }

if(defined($stopcol))
  {
    if($stopcol =~ /\D/ || $stopcol eq '')
      {
	error("Invalid column 2 (-d): [$stopcol]");
	usage(1);
	quit(2);
      }
    else
      {$stopcol--}
  }


while(nextFileCombo())
  {
    #If startcol or stopcol are undefined, they will be set anew for each input
    #file
    my $c1 = $startcol;
    my $c2 = $stopcol;

    my $infile  = getInfile($iid);
    my $outfile = getOutfile($ttid);

    openIn(*IN,$infile)    || next;
    openOut(*OUT,$outfile) || next;

    my $err = 0;
    my $line_num = 0;

    foreach my $pair (map {chomp;[split(/\t/,$_,-1)]} getLine(*IN))
      {
	$line_num++;

	if(scalar(@$pair) == 0 || $pair->[0] =~ /^\s*#/)
	  {
	    print(join("\t",@$pair),"\n");
	    next;
	  }

	if(!defined($c1) || !defined($c2))
	  {
	    if(scalar(@$pair) > 3 || scalar(@$pair) < 2)
	      {
		error("There are [",scalar(@$pair),"] columns in file ",
		      "[$infile].  Both -c and -d are required.  Unable to ",
		      "process file.",
		      {DETAIL => ("This number of columns was detected on " .
				  "line [$line_num].")});
		$err = 1;
	      }
	    elsif(scalar(@$pair) == 2)
	      {
		if(!defined($c1))
		  {$c1 = 0}
		if(!defined($c2))
		  {$c2 = 1}
	      }
	    elsif(scalar(@$pair) == 3)
	      {
		if(!defined($c1))
		  {$c1 = 1}
		if(!defined($c2))
		  {$c2 = 2}
	      }
	  }

	if(scalar(@$pair) <= $c1 || scalar(@$pair) <= $c2)
	  {
	    error("Not enough columns on line [$line_num]: [",
		  join("\t",@$pair),"].  Columns required: [",($c1+1),",",
		  ($c2+1),"].  Leaving unchanged.");
	    print(join("\t",@$pair),"\n");
	    next;
	  }
	elsif($pair->[$c1] !~ /\d/ || $pair->[$c2] !~ /\d/)
	  {
	    error("Invalid coordinate values on line [$line_num]: [",
		  join("\t",@$pair),"].  Leaving unchanged.");
	    print(join("\t",@$pair),"\n");
	    next;
	  }

	my($start,$stop) = ($pair->[$c1] <= $pair->[$c2] ?
			    (((($pair->[$c1] - $s) < 1) ?
			      1 : ($pair->[$c1] - $s)),
			     ($pair->[$c2] + $s)) :
			    (($pair->[$c1] + $s),
			     ((($pair->[$c2] - $s) < 1) ?
			      1 : ($pair->[$c2] - $s))));

	$pair->[$c1] = $start;

	if($c1 == $c2)
	  {push(@$pair,$stop)}
	else
	  {$pair->[$c2] = $stop}

	print(join("\t",@$pair),"\n");
      }

    closeIn(*IN);
    closeOut(*OUT);
  }
