#!/usr/bin/perl

use strict;
use warnings;

use lib qw(
  /home/ardavey/perlmods
  /home/ardavey/perl5/lib/perl5
);

use 5.010;

use WWW::Mechanize;
use Spreadsheet::Read;
use Storable;

my $source_page = 'https://www.gov.scot/publications/coronavirus-covid-19-trends-in-daily-data/';
my $content_file = '/tmp/covid-ss.xlsx';
my $data_file = '/tmp/covid-data';

my $m = WWW::Mechanize->new();

$m->get( $source_page );
my $ss_link = $m->find_link( text_regex => qr/COVID-19 data by NHS Board/ );
$m->get( $ss_link->url_abs(), ':content_file' => $content_file );

my $book = Spreadsheet::Read->new( $content_file );
my $sheet = $book->sheet(3);

my $row = $sheet->maxrow;
my $date = $sheet->cell( "A$row" );

my %data = ();

foreach my $column ( 2..16 ) {
  my $region = $sheet->cell( $column, 3 );
  $region =~ s/^NHS //;
  $data{regional}->{$region } = {
    today => $sheet->cell( $column, $row ),
    yesterday => $sheet->cell( $column, $row-1 ),
    delta => $sheet->cell( $column, $row ) - $sheet->cell( $column, $row-1 ),
  };
}

store( \%data, $data_file );
