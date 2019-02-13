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

our $VERSION = '2.2';

setScriptInfo(VERSION => $VERSION,
              CREATED => 'circa 2010',
              AUTHOR  => 'Robert William Leach',
              CONTACT => 'rleach@princeton.edu',
              COMPANY => 'Princeton University',
              LICENSE => 'Copyright 2019',
              HELP    => ('This script pads a pair of coordinates by a ' .
			  'given amount, e.g. padding coordinates 200,300 ' .
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
addOption(GETOPTKEY   => 'p|pad|pad-both-size=i',
	  GETOPTVAL   => \$s,
	  SMRY_DESC   => 'Pad amount.',
	  DETAIL_DESC => ('Pad amount.  This value will be subtracted from ' .
			  'the lesser coordinate and added to the greater ' .
			  'coordinate (whichever coordinate column they are ' .
			  'in).'));

my($pad_start);
addOption(GETOPTKEY   => 'b|pad-start=i',
	  GETOPTVAL   => \$pad_start,
	  DETAIL_DESC => ('Pad amount for the start coordinate.  Requires -d/' .
			  '--strand-column to determine whether the lesser ' .
			  'or greater coordinate is the start coordinate.  ' .
			  'This value will either be subtracted or added to ' .
			  'the start coordinate value, depending on whether ' .
			  'the start coordinate is the lesser or greater ' .
			  'value.  Mutually exclusive with -p, -f, -s, -l, ' .
			  'and -g.'));

my($pad_stop);
addOption(GETOPTKEY   => 'e|pad-stop=i',
	  GETOPTVAL   => \$pad_stop,
	  DETAIL_DESC => ('Pad amount for the stop coordinate.  Requires -d/' .
			  '--strand-column to determine whether the lesser ' .
			  'or greater coordinate is the stop coordinate.  ' .
			  'This value will either be subtracted or added to ' .
			  'the stop coordinate value, depending on whether ' .
			  'the stop coordinate is the lesser or greater ' .
			  'value.  Mutually exclusive with -p, -f, -s, -l, ' .
			  'and -g.'));

my($pad_lesser);
addOption(GETOPTKEY   => 'l|pad-lesser=i',
	  GETOPTVAL   => \$pad_lesser,
	  DETAIL_DESC => ('Pad amount for the lesser coordinate.  This value ' .
			  'will be subtracted from the lesser coordinate ' .
			  'value.  Mutually exclusive with -p, -f, -s, -b, ' .
			  'and -e.'));

my($pad_greater);
addOption(GETOPTKEY   => 'g|pad-greater=i',
	  GETOPTVAL   => \$pad_greater,
	  DETAIL_DESC => ('Pad amount for the greater coordinate.  This ' .
			  'value will be added to the greater coordinate ' .
			  'value.  Mutually exclusive with -p, -f, -s, -b, ' .
			  'and -e.'));

my($pad_first);
addOption(GETOPTKEY   => 'f|pad-first=i',
	  GETOPTVAL   => \$pad_first,
	  DETAIL_DESC => ('Pad amount for the first coordinate column ' .
			  'specified with -c.  This value will either be ' .
			  'subtracted or added to the first coordinate ' .
			  'column values, depending on whether they have ' .
			  'the lesser or greater value on each line, ' .
			  'respectively.  Mutually exclusive with -p, -b, ' .
			  '-e, -l, and -g.'));

my($pad_second);
addOption(GETOPTKEY   => 's|pad-second=i',
	  GETOPTVAL   => \$pad_second,
	  DETAIL_DESC => ('Pad amount for the second coordinate column ' .
			  'specified with -c.  This value will either be ' .
			  'subtracted or added to the second coordinate ' .
			  'column values, depending on whether they have the ' .
			  'lesser or greater value on each line, ' .
			  'respectively.  Mutually exclusive with -p, -b, ' .
			  '-e, -l, and -g.'));

my $add_col_strategy = 'insert';
addOption(GETOPTKEY   => 'add-stop-strategy',
	  GETOPTVAL   => \$add_col_strategy,
	  TYPE        => 'enum',
	  REQUIRED    => 0,
	  ADVANCED    => 1,
	  DEFAULT     => $add_col_strategy,
	  ACCEPTS     => ['delimiter','insert'],
	  SMRY_DESC   => 'How to add a stop when padding 1 coordinate column.',
	  DETAIL_DESC => ('If padding a single coordinate, join the ' .
			  'coordinates in the same column with an --add-stop-' .
			  'delimiter or insert an extra column where the ' .
			  'coordinate column currently is.  Note, the ' .
			  'original column coordinate value is changed in ' .
			  'all cases.'));

my $delimiter = '..';
addOption(GETOPTKEY   => 'add-stop-delimiter',
	  GETOPTVAL   => \$delimiter,
	  TYPE        => 'string',
	  REQUIRED    => 0,
	  ADVANCED    => 1,
	  DEFAULT     => $delimiter,
	  SMRY_DESC   => 'Delimiter to use when padding a single coordinate.',
	  DETAIL_DESC => ('If --add-stop-strategy is "delimiter", use this ' .
			  'delimiter when joining padded coordinates in a ' .
			  'single column.'));

my($coord1col,$coord2col);
my $coordcols = [];
addArrayOption(GETOPTKEY   => 'c|coord-columns=s',
	       GETOPTVAL   => $coordcols,
	       DEFAULT     => 'auto*',
	       REQUIRED    => 0,
	       SMRY_DESC   => ('Column numbers of coordinate columns.  ' .
			       'Supply twice.  * See --extended usage.'),
	       DETAIL_DESC => ('Column numbers of coordinate columns.  ' .
			       'Either supply twice (once for each ' .
			       'coordinate column) or supply the 2 values ' .
			       'is a single space-delimited string ' .
			       "surrounded by quotes.\n\n" .
			       '* Defaults to the first & second columns if ' .
			       'there are only 2 columns, or the second & ' .
			       'third column if there are only 3 columns.  ' .
			       'If there is 1 column, it defaults to that ' .
			       'one column for both.  Required if there are ' .
			       'more than 3 columns.'));

my($dircol);
addOption(GETOPTKEY   => 'd|strand-column',
	  TYPE        => 'integer',
	  GETOPTVAL   => \$dircol,
	  REQUIRED    => 0,
	  DETAIL_DESC => ('Strand column number (for the column containing ' .
			  'values such as "+"/"-", ""/"c", "plus"/"minus", ' .
			  'or "forward"/"reverse").  Strand information is ' .
			  'only used for 3 things:  1. If -b or -e are ' .
			  'supplied, the strand is used to determine whish ' .
			  'of the lesser/greater coordinates is the start/' .
			  'stop.  2. When the start and stop coordinates ' .
			  'have the same value, the strand is used to ' .
			  'determine whether the padded coordinate order is ' .
			  'lesser/greater (strand "+") or greater/lesser ' .
			  '(strand "-").  3. When --coord-order is ' .
			  '"true-start-stop" (which is the default), the ' .
			  'strand determines whether the lesser value ends ' .
			  'up in the first (/start) or second (/stop) ' .
			  'coordinate column.\n\nCircular chromosomes are ' .
			  'not currently supported.'));

my $coord_order = 'keep';
addOption(GETOPTKEY   => 'coord-order',
	  GETOPTVAL   => \$coord_order,
	  TYPE        => 'enum',
	  REQUIRED    => 0,
	  ADVANCED    => 1,
	  DEFAULT     => $coord_order,
          ACCEPTS     => ['keep','true-start-stop','lesser-greater'],
	  SMRY_DESC   => 'Ordering strategy of the output coordinate columns.',
	  DETAIL_DESC => ('Determines whether the lesser and greater ' .
			  'coordinates end up in the first (start) or ' .
			  'second (stop) coordinate column.  "keep" will ' .
			  'leave the lesser/greater order how it was in the ' .
			  'input file (unless the coordinates are equal, in ' .
			  'which case, order depends on whether -d has been ' .
			  'provided - without -f, defaults to "lesser-' .
			  'greater", otherwise "true-start-stop").  Note the ' .
			  'first -c column is always treated as the start ' .
			  'column and the second is treated as the stop ' .
			  'column.'));

my $ttid =
  addOutfileTagteamOption(GETOPTKEY_SUFF   => 'o|outfile-suffix=s',
			  GETOPTKEY_FILE   => 'outfile=s',
			  FILETYPEID       => $iid,
			  PRIMARY          => 1,
			  DETAIL_DESC_SUFF => ('Extension appended to file ' .
					       'submitted via -i.'),
			  DETAIL_DESC_FILE => 'Outfile.',
			  FORMAT_DESC      => ('Tab delimited text.  Note, ' .
					       'carriage returns will be ' .
					       'changed to newline ' .
					       'characters.'));

processCommandLine();

my $fatal = 0;

my $both = (defined($s)                                   ? 1 : 0);
my $be   = (defined($pad_start)  || defined($pad_stop)    ? 1 : 0);
my $fs   = (defined($pad_first)  || defined($pad_second)  ? 1 : 0);
my $lg   = (defined($pad_lesser) || defined($pad_greater) ? 1 : 0);
my $sumt = $both + $be + $fs + $lg;

if($sumt == 0)
  {
    error("A pad amount is required (see -p, -b or -e, -l or -g, or -f or ",
	  "-s).");
    $fatal = 1;
  }
elsif($sumt > 1)
  {
    error("Mutually exclusive pad amounts supplied.  The following groups of ",
	  "options are incompatible with one another: [(",
	  join('),(',
	       grep {defined} (($both ? '-p' : undef),
			       ($be ? ($pad_start && $pad_stop ? '-b,-e' :
				       ($pad_start ? '-b' : '-e')) : undef),
			       ($fs ? ($pad_first && $pad_second ? '-f,-s' :
				       ($pad_first ? '-f' : '-s')) : undef),
			       ($lg ? ($pad_lesser && $pad_greater ? '-l,-g' :
				       ($pad_lesser ? '-l' : '-g')) : undef))),
	  ")].",
	  {DETAIL => join('',('-p, -b or -e, -f or -s, and -l or -g are ',
			      'mutually exclusive.  E.g. You can use -b and ',
			      '-e together to specify a pad size for the ',
			      'start and stop coordinates respectively, but ',
			      'the use either one means you cannot use any of ',
			      'the others (-p, -f, -s, -l, or -g) because ',
			      'they are different strategies for specifying ',
			      'the pad size and may conflict.'))});
    $fatal = 1;
  }

if($be && !defined($dircol))
  {
    error("A strand column (-d) must be supplied if either a start or stop ",
	  "coordinate column (-b or -e) are supplied.");
    $fatal = 1;
  }

if($be && scalar(@$coordcols) != 2)
  {
    error("Exactly 2 coordinate columns must be specified if either -b or -e ",
	  "are supplied, but [",scalar(@$coordcols),"] coordinate columns ",
	  "were supplied.",
	  {DETAIL =>
	   join('',('Some tab-deliminted formats always put the lesser and ',
		    'greater coordinates in specific columns regardless of ',
		    'strand while other formats put the start and stop in ',
		    'specific columns regardless of which coordinate is ',
		    'greater.  To be sure we know whether to add or subtract ',
		    'the pad value, both columns are required.'))});
    $fatal = 1;
  }

if(defined($s) && $s < 1)
  {
    error("Invalid pad size (-p): [$s].  Must be an unsigned integer.");
    $fatal = 1;
  }

if(defined($pad_first) && $pad_first < 1)
  {
    error("Invalid pad size (-f): [$pad_first].  Must be an unsigned integer.");
    $fatal = 1;
  }

if(defined($pad_second) && $pad_second < 1)
  {
    error("Invalid pad size (-s): [$pad_second].  Must be an unsigned ",
	  "integer.");
    $fatal = 1;
  }

if(defined($pad_start) && $pad_start < 1)
  {
    error("Invalid pad size (-b): [$pad_start].  Must be an unsigned integer.");
    $fatal = 1;
  }

if(defined($pad_stop) && $pad_stop < 1)
  {
    error("Invalid pad size (-e): [$pad_stop].  Must be an unsigned integer.");
    $fatal = 1;
  }

if(defined($pad_lesser) && $pad_lesser < 1)
  {
    error("Invalid pad size (-l): [$pad_lesser].  Must be an unsigned ",
	  "integer.");
    $fatal = 1;
  }

if(defined($pad_greater) && $pad_greater < 1)
  {
    error("Invalid pad size (-g): [$pad_greater].  Must be an unsigned ",
	  "integer.");
    $fatal = 1;
  }

if(scalar(@$coordcols))
  {
    if(scalar(@$coordcols) == 2)
      {($coord1col,$coord2col) = @$coordcols}
    elsif(scalar(@$coordcols) == 1)
      {$coord1col = $coordcols->[0]}
    else
      {
	error("Too many coordinate columns supplied to -c.  These column ",
	      "numbers will be ignored: [",
	      join(',',@{$coordcols}[2..$#{$coordcols}]),"].");
	($coord1col,$coord2col) = @{$coordcols}[0,1];
      }
  }

if(defined($coord1col))
  {
    if($coord1col =~ /\D/ || $coord1col eq '' || $coord1col < 1)
      {
	error("Invalid coordinate column (-c): [$coord1col].  Must be an ",
	      "integer greater than 0.");
	$fatal = 1;
      }
    else
      {$coord1col--}
  }

if(defined($coord2col))
  {
    if($coord2col =~ /\D/ || $coord2col eq '' || $coord2col < 1)
      {
	error("Invalid coordinate column (-c): [$coord2col].  Must be an ",
	      "integer greater than 0.");
	$fatal = 1;
      }
    else
      {$coord2col--}
  }

if(defined($dircol))
  {
    if($dircol =~ /\D/ || $dircol eq '' || $dircol < 1)
      {
	error("Invalid strand column (-d): [$dircol].  Must be an integer ",
	      "greater than 0.");
	$fatal = 1;
      }
    else
      {$dircol--}
  }

if($add_col_strategy eq 'delimiter' && $delimiter eq '')
  {
    error("--add-stop-strategy cannot be an empty string.");
    $fatal = 1;
  }

if($fatal)
  {quit(1)}

my $past_header = 0;

while(nextFileCombo())
  {
    #If startcol or stopcol are undefined, they will be set anew for each input
    #file
    my $c1 = $coord1col;
    my $c2 = $coord2col;

    my $infile  = getInfile($iid);
    my $outfile = getOutfile($ttid);

    openIn(*IN,$infile)    || next;
    openOut(*OUT,$outfile) || next;

    my $err = 0;
    my $line_num = 0;
    my $coord_order_guesses = 0;
    my $start_stop_evidence = 0;
    my $less_great_evidence = 0;
    my $data_count = 0;

    foreach my $row (map {chomp;[split(/\t/,$_,-1)]} getLine(*IN))
      {
	$line_num++;

	#If commented or empty line
	if((scalar(@$row) == 1 && $row->[0] eq '') || $row->[0] =~ /^\s*#/)
	  {
	    #If we're past the header or --header is true
	    if(!$past_header && headerRequested())
	      {print(join("\t",@$row),"\n")}
	    next;
	  }

	$past_header = 1;

	if(scalar(@$row) <= $c1 || scalar(@$row) <= $c2 ||
	   $row->[$c1] !~ /\d/  || $row->[$c2] !~ /\d/  ||
	   (defined($dircol) && scalar(@$row) <= $dircol))
	  {
	    print(join("\t",@$row),"\n");
	    next;
	  }

	my($strand);
	if(defined($dircol))
	  {$strand = $row->[$dircol]}

	my $orig_order = ($row->[$c1] < $row->[$c2] ? 'forward' :
			  ($row->[$c1] > $row->[$c2] ? 'reverse' :
			   (defined($dircol) ?
			    (getDir($strand) eq 'unknown' ?
			     'forward' : getDir($strand)) : 'forward')));

	my($lesser,$greater) = pad($row->[$c1],$row->[$c2],
				   $orig_order,
				   $strand,
				   $both,$be,$fs,$lg,
				   $s,
				   $pad_start,$pad_stop,
				   $pad_first,$pad_second,
				   $pad_lesser,$pad_greater);

	my($start,$stop);
	if($coord_order eq 'keep')
	  {
	    if($orig_order eq 'forward')
	      {($start,$stop) = ($lesser,$greater)}
	    else
	      {($start,$stop) = ($greater,$lesser)}

	    if($row->[$c1] > $row->[$c2])
	      {$start_stop_evidence++}
	    if($row->[$c1] < $row->[$c2] &&
	       defined($dircol) && $strand eq 'reverse')
	      {$less_great_evidence++}
	    if($row->[$c1] == $row->[$c2])
	      {$coord_order_guesses++}
	  }
	elsif($coord_order eq 'lesser-greater')
	  {($start,$stop) = ($lesser,$greater)}
	elsif($coord_order eq 'true-start-stop')
	  {
	    if(defined($dircol))
	      {
		#Impose correct order given the strand (assuming linear genome)
		my $new_order = (getDir($strand) ne 'unknown' ?
				 getDir($strand) :
				 (#Infer order from original coord order
				  $row->[$c1] <= $row->[$c2] ?
				  'forward' : 'reverse'));

		if($new_order eq 'forward')
		  {($start,$stop) = ($lesser,$greater)}
		else
		  {($start,$stop) = ($greater,$lesser)}
	      }
	    else
	      {
		#Infer strand from original order
		if($row->[$c1] <= $row->[$c2])
		  {($start,$stop) = ($lesser,$greater)}
		else
		  {($start,$stop) = ($greater,$lesser)}
	      }
	  }

	$row->[$c1] = $start;

	if($c1 == $c2)
	  {
	    if($add_col_strategy eq 'insert')
	      {
		if($c1 == $#{$row})
		  {push(@$row,$stop)}
		else
		  {splice(@$row,$c1+1,0,$stop)}
	      }
	    elsif($add_col_strategy eq 'delimiter')
	      {$row->[$c1] .= $delimiter . $stop}
	    else
	      {error("Invalid --add-stop-strategy value: [$add_col_strategy].")}
	  }
	else
	  {$row->[$c2] = $stop}

	$data_count++;
	print(join("\t",@$row),"\n");
      }

    if($coord_order_guesses && !$start_stop_evidence && $less_great_evidence)
      {error("[$coord_order_guesses] 1nt long coordinate pairs were output in ",
	     "true-start-stop order, but the rest of the coordinate pairs in ",
	     "file [$infile] appear to be in lesser-greater order.  Please ",
	     "rerun with `--coord-order lesser-greater --overwrite` to make ",
	     "the coordinate order of the output file consistent.")}
    elsif($coord_order_guesses == $data_count)
      {warning("Could not determine intended coordinate order in the ",
	     "coordinate column (e.g. first coordinate column is either ",
	     "always the lesser coordinate or the true start coordinate).  ",
	     "All padded coordinates have been output in true-start-stop ",
	     "order.  Rerun with `--coord-order lesser-greater --overwrite` ",
	     "to change the coordinate order.")}

    closeIn(*IN);
    closeOut(*OUT);
  }

#Returns forward, reverse, or unknown given a string that is any of: 123..456,
#123..456c, +, -, plus, minus, for, forward, rev, reverse.
sub getDir
  {
    my $strand    = $_[0];
    my $suppress  = $_[1];
    my $direction = 'unknown'; #default

    if(!defined($strand))
      {
	error("Strand required.");
	return($direction);
      }

    #If this is a coordinate column, look for 'c'
    if($strand =~ /\d/)
      {
	if($strand =~ /c/)
	  {$direction = 'reverse'}
	else
	  {$direction = 'forward'}
      }
    else
      {
	if($strand =~ /^\s*[\-cmr]/i)
	  {$direction = 'reverse'}
	elsif($strand =~ /^\s*[+pf]/i)
	  {$direction = 'forward'}
	else
	  {warning("Unable to determine strand from [$strand].")
	     unless($suppress)}
      }

    return($direction);
  }

sub pad
  {
    my $c1          = $_[0];
    my $c2          = $_[1];
    my $orig_order  = $_[2];
    my $strand      = $_[3];
    my $both        = $_[4];
    my $be          = $_[5];
    my $fs          = $_[6];
    my $lg          = $_[7];
    my $s           = $_[8];
    my $pad_start   = $_[9];
    my $pad_stop    = $_[10];
    my $pad_first   = $_[11];
    my $pad_second  = $_[12];
    my $pad_lesser  = $_[13];
    my $pad_greater = $_[14];

    my($lesser,$greater) = ($row->[$c1] <= $row->[$c2] ?
			    ($row->[$c1],$row->[$c2]) :
			    ($row->[$c2],$row->[$c1]));

    if($both)
      {
	$lesser  -= $s;
	$greater += $s;
      }
    elsif($be)
      {
	my $lesser_is_start = 1;
	#Determine whether the larger or lesser coord is the start
	if(defined($strand))
	  {
	    if($strand eq 'forward')
	      {$lesser_is_start = 1}
	    elsif($strand eq 'reverse')
	      {$lesser_is_start = 0}
	    #Infer start column from coord order, defaulting to forward
	    elsif($orig_order eq 'reverse')
	      {$lesser_is_start = 0}
	  }
	else
	  {
	    #Infer start column from coord order, defaulting to forward
	    if($orig_order eq 'reverse')
	      {$lesser_is_start = 0}
	  }
	if(defined($pad_start))
	  {
	    if($lesser_is_start)
	      {$lesser -= $pad_start}
	    else
	      {$greater += $pad_start}
	  }
	if(defined($pad_stop))
	  {
	    if($lesser_is_start)
	      {$greater += $pad_stop}
	    else
	      {$lesser -= $pad_stop}
	  }
      }
    elsif($fs)
      {
	my $lesser_is_first = 1;
	if($row->[$c1] > $row->[$c2])
	  {$lesser_is_first = 0}
	if(defined($pad_first))
	  {
	    if($lesser_is_first)
	      {$lesser -= $pad_first}
	    else
	      {$greater += $pad_first}
	  }
	if(defined($pad_second))
	  {
	    if($lesser_is_first)
	      {$greater += $pad_second}
	    else
	      {$lesser -= $pad_second}
	  }
      }
    elsif($lg)
      {
	if(defined($pad_lesser))
	  {$lesser -= $pad_lesser}
	if(defined($pad_greater))
	  {$greater += $pad_greater}
      }
    else
      {error("No pad strategy supplied.")}

    return($lesser,$greater);
  }
