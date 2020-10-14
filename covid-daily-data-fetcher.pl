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
my $tmp_dir = '/home/ardavey/tmp/';

my $nhs_board_ss_file = $tmp_dir.'covid-nhs-board.xlsx';
my $nhs_board_data_file = $tmp_dir.'covid-nhs-board.data';

my $daily_trends_ss_file = $tmp_dir.'covid-daily-trends.xlsx';
my $testing_data_file = $tmp_dir.'covid-testing.data';
my $deaths_data_file = $tmp_dir.'covid-deaths.data';


my $m = WWW::Mechanize->new();

# Find the spreadsheet download links
$m->get( $source_page );
my $nhs_board_ss_link = $m->find_link( text_regex => qr/COVID-19 data by NHS Board/ );
my $daily_trends_ss_link = $m->find_link( text_regex => qr/Trends in daily COVID-19 data/ );

# Download the NHS board spreadsheet
$m->get( $nhs_board_ss_link->url_abs(), ':content_file' => $nhs_board_ss_file );

# Parse and pull out only the sheet we're interested in
my $nhs_board_book = Spreadsheet::Read->new( $nhs_board_ss_file );
my $nhs_board_sheet = $nhs_board_book->sheet(3);

# Download the daily trends spreadsheet
$m->get( $daily_trends_ss_link->url_abs(), ':content_file' => $daily_trends_ss_file );

# Parse and pull out only the sheets we're interested in
my $daily_trends_book = Spreadsheet::Read->new( $daily_trends_ss_file );
my $testing_sheet = $daily_trends_book->sheet(6);
my $deaths_sheet = $daily_trends_book->sheet(14);

# Store all sheets to file for the website to read
store( $nhs_board_sheet, $nhs_board_data_file );
store( $testing_sheet, $testing_data_file );
store( $deaths_sheet, $deaths_data_file );

# Delete the spreadsheet downloads
unlink( $nhs_board_ss_file, $daily_trends_ss_file );
