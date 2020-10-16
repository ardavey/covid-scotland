#!/usr/bin/perl

use strict;
use warnings;

use lib qw(
  /home/ardavey/perlmods
  /home/ardavey/perl5/lib/perl5
);

use 5.010;

use Spreadsheet::Read;
use Storable;
use Time::HiRes qw( gettimeofday tv_interval );
use List::Util qw( shuffle );

use Data::Dumper;

my $t0 = [gettimeofday];

my $tmp_dir = '/home/ardavey/tmp/';

my $source_page = 'https://www.gov.scot/publications/coronavirus-covid-19-trends-in-daily-data/';
my $nhs_board_data_file = $tmp_dir.'covid-nhs-board.data';

my $sheet = retrieve( $nhs_board_data_file );

my $row = $sheet->maxrow();
my $date = $sheet->cell( "A$row" );

my %nhs_board_data = ();

foreach my $column ( 2..16 ) {
  my $nhs_board = $sheet->cell( $column, 3 );
  $nhs_board =~ s/^NHS //;
  $nhs_board_data{ $nhs_board } = {
    today => $sheet->cell( $column, $row ),
    yesterday => $sheet->cell( $column, $row-1 ),
    delta => $sheet->cell( $column, $row ) - $sheet->cell( $column, $row-1 ),
  };
}


print "Content-type:text/html\r\n\r\n";

say <<'HTML';
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css" integrity="sha384-JcKb8q3iqJ61gNV9KGb8thSsNjpSL0n8PARn9HuZOnIxN0hoP+VmmDGMN5t9UJ0Z" crossorigin="anonymous">

    <!-- Chart.js -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js@2.8.0"></script>

    <title>COVID-19 in Scotland</title>
  </head>
  <body>
  
<div class="container">
HTML

say <<HTML;
<h3>COVID-19 in Scotland</h3>

<h4>New Cases Today by NHS Board</h4>

<p>There were $nhs_board_data{Scotland}->{delta} new cases of COVID-19 recorded in Scotland on $date.</p>
HTML

my @nhs_boards = keys %nhs_board_data;
my @ordered_nhs_boards = sort { $nhs_board_data{$b}->{delta} <=> $nhs_board_data{$a}->{delta} or $a cmp $b } @nhs_boards;
shift @ordered_nhs_boards;

say '<p><div class="row">';

foreach my $board ( @ordered_nhs_boards ) {
  last if ( $nhs_board_data{$board}->{delta} == 0 );
  say "<div class='col-8'>$board</div>";
  say "<div class='col-4'>$nhs_board_data{$board}->{delta}</div>";
}

say <<HTML;

</div></p>

<p><small>Data extracted from <a href='$source_page'>Scottish Government website</a>.<br />
The source site is updated daily at 14:00 UK time - this site updates at 14:05.</small></p>

<hr width="75%" />

<h4>Graphs</h4>

<ul class="nav nav-tabs" id="myTab" role="tablist">
    <li class="nav-item">
        <a class="nav-link active" id="nhs-board-graph-tab" data-toggle="tab" href="#nhsboardgraph" role="tab" aria-controls="nhsboardgraph" aria-selected="true">Cumulative by NHS Board</a>
    </li>
    <li class="nav-item">
        <a class="nav-link" id="scotland-graph-tab" data-toggle="tab" href="#nationalgraph" role="tab" aria-controls="nationalgraph" aria-selected="false">Cumulative & Daily National</a>
    </li>
</ul>

<div class="tab-content" id="myTabContent">
    <br />
    <div class="tab-pane fade show active" id="nhsboardgraph" role="tabpanel" aria-labelledby="nhs-board-graph-tab">
    
HTML

my @dates = $sheet->column( 1 );
( undef, undef, undef, @dates ) = @dates;

# Convert YYYY-MM-DD to DD/MM
foreach ( @dates ) {
  $_ =~ s!(\d{4})-(\d{2})-(\d{2})!$3/$2!;
}

my $labels = "'".join( "', '", @dates )."'";

my @colours = shuffle( '#ff0029', '#377eb8', '#66a61e', '#984ea3', '#00d2d5', '#ff7f00', '#af8d00', '#7f80cd', '#b3e900', '#c42e60', '#a65628', '#f781bf', '#8dd3c7', '#bebada' );

say <<HTML;
<canvas id="regionalChart" width="100%" height="70px"></canvas>

<script>
var ctx = document.getElementById('regionalChart').getContext('2d');
var myChart = new Chart(ctx, {
    type: 'line',
    data: {
        labels: [$labels],
        datasets: [
HTML

foreach my $col ( 2..15 ) {
  my @cells = $sheet->cellcolumn( $col );
  my ( undef, undef, $label, @values ) = @cells;
  map { $_ =~ s/\*/0/g } @values;
  $label =~ s/^NHS //;
  my $values = join( ", ", @values );
  my $colour = $colours[$col-2];
  print <<DATASET;
        {
            label: '$label',
            backgroundColor: '$colour',
            borderColor: '$colour',
            borderWidth: 1,
            data: [$values],
            fill: false,
            pointRadius: 1,
            pointHoverRadius: 2,
        },
DATASET

}

say <<HTML;
      ]
    },
    options: {
      responsive: true,
      title: {
        display: true,
        text: 'Cumulative Cases by NHS Board'
      },
      legend: {
        display: false,
        position: 'bottom'
      },
      scales: {}
    }
});
</script>

    </div>
    <div class="tab-pane fade" id="nationalgraph" role="tabpanel" aria-labelledby="national-graph-tab">

<canvas id="nationalChart" width="100%" height="70px"></canvas>

<script>
var ctx = document.getElementById('nationalChart').getContext('2d');
var myChart = new Chart(ctx, {
    type: 'bar',
    data: {
        labels: [$labels],
        datasets: [
HTML

my @cells = $sheet->cellcolumn( 16 );
my ( undef, undef, undef, @values ) = @cells;
map { $_ =~ s/\*/0/g } @values;
my $values = join( ", ", @values );

print <<DATASET;
      {
          type: 'line',
          label: 'Cumulative cases',
          backgroundColor: 'darkblue',
          borderColor: 'darkblue',
          borderWidth: 1,
          data: [$values],
          fill: false,
          pointRadius: 1,
          pointHoverRadius: 2,
          yAxisID: 'y-axis-1',
      },
DATASET

my @deltas = ( 0 );
foreach my $i ( 1..$#values ) {
  push @deltas, $values[$i]-$values[$i-1];
}
my $deltas = join( ', ', @deltas );

# remove anomaly
$deltas =~ s/, 2275,/, 0,/;

print <<DATASET;
      {
          type: 'bar',
          label: 'New cases',
          backgroundColor: 'lightblue',
          borderColor: 'lightblue',
          borderWidth: 0,
          data: [$deltas],
          yAxisID: 'y-axis-2',
      },
DATASET


say <<'HTML';
      ]
    },
    options: {
      responsive: true,
      legend: {
        display: false,
        position: 'bottom'
      },
      title: {
        display: true,
        text: 'Cumulative Cases and Cases Per Day - National'
      },
      scales: {
        yAxes: [{
          type: 'linear',
          display: true,
          position: 'left',
          id: 'y-axis-1',
        }, {
          type: 'linear',
          display: true,
          position: 'right',
          id: 'y-axis-2',

          // grid line settings
          gridLines: {
            drawOnChartArea: false, // only want the grid lines for one axis to show up
          },
        }],
      }
    }
});
</script>

    </div>
</div>

<hr width="75%" />

<p><small>Note: The spike on 15 June 2020 is due to the inclusion of results from the UK Gov testing programme.
Prior to this date, figures only include those tested through NHS labs.</small></p>

</div>

    <!-- Bootstrap -->
    <script src="https://code.jquery.com/jquery-3.5.1.slim.min.js" integrity="sha384-DfXdz2htPH0lsSSs5nCTpuj/zy4C+OGpamoFVy38MVBnE+IbbVYUew+OrCXaRkfj" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/popper.js@1.16.1/dist/umd/popper.min.js" integrity="sha384-9/reFTGAW83EW2RDu2S0VKaIzap3H66lZH81PoYlFhbGU+6BZp6G7niu735Sk7lN" crossorigin="anonymous"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js" integrity="sha384-B4gt1jrGC7Jh4AgTPSdUtOBvfO8shuf57BaghqFfPlYxofvL8/KUEfYiJOMMV+rV" crossorigin="anonymous"></script>
  </body>
</html>
HTML

say "<!-- " . tv_interval( $t0 ) . " seconds -->";
