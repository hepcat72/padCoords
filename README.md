# padCoords
Expand coordinates in a tab-delimited file, regardless of coordinate order.

## WHAT IS THIS:

This script pads a pair of coordinates by a given ammount, e.g. padding coordinates 200,300 by 100 would change the coordinates to 100,400.  Order of the coordinates is unimportant, e.g. padding 300,200 by 100 would yield 400,100.

## INSTALLATION

perl Makefile.PL
make
sudo make install

## USAGE

padCoords.pl -s 10 coord_file

## INPUT

Example (tab delimited: 2 columns of coordinates):

    6   100
    105 222
    252 404

## OUTPUT (with -s 10)

    1   110
    95  232
    242 414
