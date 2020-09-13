#!/usr/bin/perl

use strict;
use warnings;

use lib qw(
  /home/ardavey/perlmods
  /home/ardavey/perl5/lib/perl5
);

use WWW::Mechanize;
use Spreadsheet::Read;

print "Content-type:text/plain\r\n\r\n";

my $source_page = 'https://www.gov.scot/publications/coronavirus-covid-19-trends-in-daily-data/';

my $m = WWW::Mechanize->new();

$m->get( $source_page );
my $ss_link = $m->find_link( text_regex => qr/COVID-19 data by NHS Board/ );
$m->get( $ss_link->url_abs(), ':content_file' => '/tmp/covid-ss.xlsx' );

my $book = Spreadsheet::Read->new( '/tmp/covid-ss.xlsx' );
my $sheet = $book->sheet(3);

my $row = $sheet->maxrow;
my $date = $sheet->cell( "A$row" );

my %data = ();

foreach my $column ( 2..16 ) {
  my $region = $sheet->cell( $column, 3 );
  $region =~ s/^NHS //;
  $data{ $region } = {
    today => $sheet->cell( $column, $row ),
    yesterday => $sheet->cell( $column, $row-1 ),
    delta => $sheet->cell( $column, $row ) - $sheet->cell( $column, $row-1 ),
  };
}

print "$data{Scotland}->{delta} new Scottish COVID-19 cases on $date:\n\n";

my @regions = keys %data;
my @ordered_regions = sort { $data{$b}->{delta} <=> $data{$a}->{delta} or $a cmp $b } @regions;
shift @ordered_regions;

foreach my $r ( @ordered_regions ) {
  last if ( $data{$r}->{delta} == 0 );
  print "$r: $data{$r}->{delta}\n";
}
