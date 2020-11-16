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
my $deaths_data_file = $tmp_dir.'covid-deaths.data';
my $nhs_board_data_file = $tmp_dir.'covid-nhs-board.data';

my $deaths_data_sheet = retrieve( $deaths_data_file );
my $nhs_data_sheet = retrieve( $nhs_board_data_file );

# Get all the data we need for the daily count and delta per NHS board

my $nhs_board_row = $nhs_data_sheet->maxrow();
my $date = $nhs_data_sheet->cell( "A$nhs_board_row" );
$date =~ s!(\d{4})-(\d{2})-(\d{2})!$3/$2/$1!;

my %nhs_board_data = ();

foreach my $column ( 2..16 ) {
  my $nhs_board = $nhs_data_sheet->cell( $column, 3 );
  $nhs_board =~ s/^NHS //;
  $nhs_board_data{ $nhs_board } = {
    today => $nhs_data_sheet->cell( $column, $nhs_board_row ),
    yesterday => $nhs_data_sheet->cell( $column, $nhs_board_row-1 ),
    delta => $nhs_data_sheet->cell( $column, $nhs_board_row ) - $nhs_data_sheet->cell( $column, $nhs_board_row-1 ),
    delta_delta => sprintf( "%+d", ( $nhs_data_sheet->cell( $column, $nhs_board_row ) - $nhs_data_sheet->cell( $column, $nhs_board_row-1 ) ) - ( $nhs_data_sheet->cell( $column, $nhs_board_row-1 ) - $nhs_data_sheet->cell( $column, $nhs_board_row-2 ) ) ),
  };
  
  $nhs_board_data{ $nhs_board }->{delta_delta} = $nhs_board_data{ $nhs_board }->{delta_delta} eq '+0' ? '0' : $nhs_board_data{ $nhs_board }->{delta_delta};
}

# Now get the death data
my $deaths_row = $deaths_data_sheet->maxrow();

my %deaths_data = ();

( undef, undef, undef, @{ $deaths_data{dates} } ) = $deaths_data_sheet->column(1);
( undef, undef, undef, @{ $deaths_data{cumulative_deaths} } ) = $deaths_data_sheet->cellcolumn(2);

push @{ $deaths_data{delta_deaths} }, 0;

foreach my $i ( 1..$#{ $deaths_data{cumulative_deaths} } ) {
  push @{ $deaths_data{delta_deaths} }, $deaths_data{cumulative_deaths}->[$i] - $deaths_data{cumulative_deaths}->[$i-1];
}

# Convert YYYY-MM-DD to DD/MM
foreach ( @{ $deaths_data{dates} } ) {
  $_ =~ s!\d{4}-(\d{2})-(\d{2})!$2/$1!;
}

$deaths_data{labels_dates} = "'".join( "', '", @{ $deaths_data{dates} } )."'";
$deaths_data{values_cumulative_deaths} = join( ', ', @{ $deaths_data{cumulative_deaths} } );
$deaths_data{values_delta_deaths} = join( ', ', @{ $deaths_data{delta_deaths} } );
$deaths_data{new_deaths} = $deaths_data{delta_deaths}->[-1];
$deaths_data{new_deaths_plural} = $deaths_data{new_deaths} == 1 ? '' : 's';

print "Content-type:text/html\r\n\r\n";

say <<HTML;
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css" integrity="sha384-JcKb8q3iqJ61gNV9KGb8thSsNjpSL0n8PARn9HuZOnIxN0hoP+VmmDGMN5t9UJ0Z" crossorigin="anonymous">

  <!-- Chart.js -->
  <script src="https://cdn.jsdelivr.net/npm/chart.js\@2.8.0"></script>

  <title>COVID-19 in Scotland</title>
</head>
<body>
  <div class="container">
  
    <h3>COVID-19 in Scotland - $date</h3>
    
    <div class="alert alert-primary">There were <mark>$nhs_board_data{Scotland}->{delta}</mark> new cases of COVID-19 and <mark>$deaths_data{new_deaths}</mark> new confirmed death$deaths_data{new_deaths_plural} recorded in Scotland on $date.</div>
    
    <hr width="75%" />
    
    <h4>New Cases Today by NHS Board</h4>
HTML

my @nhs_boards = keys %nhs_board_data;
my @ordered_nhs_boards = sort { $nhs_board_data{$b}->{delta} <=> $nhs_board_data{$a}->{delta} or $nhs_board_data{$a}->{delta_delta} cmp $nhs_board_data{$b}->{delta_delta} or $a cmp $b } @nhs_boards;
# Luckily the "Scotland" entry appears at the start of this list so we can bin it easily
shift @ordered_nhs_boards;

say <<HTML;
<div class="table-responsive">

  <table class="table table-sm table-striped">
    <thead class="thead-light">
      <th scope="col">NHS Board</th>
      <th scope="col">New Cases <small>(Delta)</small></th>
    </thead>
    <tbody>
HTML

foreach my $board ( @ordered_nhs_boards ) {
  next if (   $nhs_board_data{$board}->{delta} == 0
           && $nhs_board_data{$board}->{delta_delta} == 0 );
  
say <<HTML;
      <tr>
        <td>$board</td>
        <td>$nhs_board_data{$board}->{delta} <small>($nhs_board_data{$board}->{delta_delta})</small></td>
      </tr>
HTML
}

say <<HTML;
    </tbody>
  </table>
</div>

<hr width="75%" />

<h4>Graphs</h4>

<ul class="nav nav-tabs" id="myTab" role="tablist">
  <li class="nav-item">
    <a class="nav-link active" id="scotland-graph-tab" data-toggle="tab" href="#nationalgraph" role="tab" aria-controls="nationalgraph" aria-selected="false">National Cases</a>
  </li>
  <li class="nav-item">
    <a class="nav-link" id="deaths-graph-tab" data-toggle="tab" href="#deathsgraph" role="tab" aria-controls="deathsgraph" aria-selected="false">National Deaths</a>
  </li>
  <li class="nav-item">
    <a class="nav-link" id="nhs-board-graph-tab" data-toggle="tab" href="#nhsboardgraph" role="tab" aria-controls="nhsboardgraph" aria-selected="true">NHS Board Cases</a>
  </li>
  <!-- <li class="nav-item">
    <a class="nav-link" id="tests-graph-tab" data-toggle="tab" href="#testsgraph" role="tab" aria-controls="testsgraph" aria-selected="false">Tests</a>
  </li> -->
</ul>

<div class="tab-content" id="myTabContent">
  <br />
  <div class="tab-pane fade" id="nhsboardgraph" role="tabpanel" aria-labelledby="nhs-board-graph-tab">
    
HTML

my @dates = $nhs_data_sheet->column( 1 );
( undef, undef, undef, @dates ) = @dates;

# Convert YYYY-MM-DD to DD/MM
foreach ( @dates ) {
  $_ =~ s!\d{4}-(\d{2})-(\d{2})!$2/$1!;
}

my $labels = "'".join( "', '", @dates )."'";

my @colours = shuffle( '#ff0029', '#377eb8', '#66a61e', '#984ea3', '#00d2d5', '#ff7f00', '#af8d00', '#7f80cd', '#b3e900', '#c42e60', '#a65628', '#f781bf', '#8dd3c7', '#bebada' );

say <<HTML;
<canvas id="regionalChart" width="100%" height="70px"></canvas>

<script>
var regionalTitle = 'Cumulative Cases by NHS Board - All Time';
var regionalLabels = [$labels];

var ctx = document.getElementById('regionalChart').getContext('2d');
var regionalChart = new Chart(ctx, {
  type: 'line',
  data: {
    labels: regionalLabels,
    datasets: [
HTML

foreach my $col ( 2..15 ) {
  my @cells = $nhs_data_sheet->cellcolumn( $col );
  my ( undef, undef, $board, @values ) = @cells;
  map { $_ =~ s/\*/0/g } @values;
  $board =~ s/^NHS //;
  my $values = join( ", ", @values );
  my $colour = $colours[$col-2];
  say <<DATASET;
      {
        label: '$board',
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
      text: regionalTitle,
    },
    tooltips: {
      mode: 'index',
      intersect: false,
      position: 'nearest',
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
HTML


# Graph of national cumulative and daily delta

my @cells = $nhs_data_sheet->cellcolumn( 16 );
my ( undef, undef, undef, @values ) = @cells;
map { $_ =~ s/\*/0/g } @values;
my $values = join( ", ", @values );

my @deltas = ( 0 );
foreach my $i ( 1..$#values ) {
  push @deltas, $values[$i]-$values[$i-1];
}
# remove anomaly
$deltas[100] = 0;
my $deltas = join( ', ', @deltas );

say <<HTML;  
<div class="tab-pane fade show active" id="nationalgraph" role="tabpanel" aria-labelledby="national-graph-tab">

<canvas id="nationalChart" width="100%" height="70px"></canvas>

<button type="button" class="btn btn-outline-info btn-sm" id="toggleZoomNational">Toggle All/Last 30 days</button>

<script>
var nationalTitle = 'National Cumulative/Daily Cases - All Time';
var nationalTitle30 = 'National Cumulative/Daily Cases - Last 30 Days';

var nationalLabels = [$labels];
var nationalDataCumulative = [$values];
var nationalDataDeltas = [$deltas];

var ctx = document.getElementById('nationalChart').getContext('2d');
var nationalChart = new Chart(ctx, {
    type: 'bar',
    data: {
        labels: nationalLabels,
        datasets: [
          {
              type: 'line',
              label: 'Cumulative cases',
              backgroundColor: 'darkblue',
              borderColor: 'darkblue',
              borderWidth: 1,
              data: nationalDataCumulative,
              fill: false,
              pointRadius: 1,
              pointHoverRadius: 2,
              yAxisID: 'y-axis-1',
          },
          {
              type: 'bar',
              label: 'New cases',
              backgroundColor: 'lightblue',
              borderColor: 'lightblue',
              borderWidth: 0,
              data: nationalDataDeltas,
              yAxisID: 'y-axis-2',
          },
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
        text: nationalTitle,
      },
      tooltips: {
        mode: 'index',
        intersect: false,
        position: 'nearest',
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

document.getElementById('toggleZoomNational').addEventListener('click', function() {
    nationalChart.options.title.text = nationalChart.options.title.text == nationalTitle ? nationalTitle30 : nationalTitle;
    nationalChart.data.labels = nationalChart.data.labels.length == 30 ? nationalLabels : nationalLabels.slice( -30 );
    nationalChart.data.datasets[0].data = nationalChart.data.datasets[0].data.length == 30 ? nationalDataCumulative : nationalDataCumulative.slice( -30 );
    nationalChart.data.datasets[1].data = nationalChart.data.datasets[1].data.length == 30 ? nationalDataDeltas : nationalDataDeltas.slice( -30 );
    nationalChart.update( { duration: 0 } );
 });

</script>

    </div>
    <div class="tab-pane fade" id="deathsgraph" role="tabpanel" aria-labelledby="deaths-graph-tab">

<canvas id="deathsChart" width="100%" height="70px"></canvas>

<button type="button" class="btn btn-outline-info btn-sm" id="toggleZoomDeaths">Toggle All/Last 30 days</button>

<script>
var title = 'National Cumulative/Daily Deaths - All Time';
var title30 = 'National Cumulative/Daily Deaths - Last 30 Days';

var labels = [$deaths_data{labels_dates}];
var dataCumulative = [$deaths_data{values_cumulative_deaths}];
var dataDeltas = [$deaths_data{values_delta_deaths}];

var ctx = document.getElementById('deathsChart').getContext('2d');
var deathsChart = new Chart(ctx, {
    type: 'bar',
    data: {
        labels: labels,
        datasets: [
          {
              type: 'line',
              label: 'Cumulative deaths',
              backgroundColor: 'darkblue',
              borderColor: 'darkblue',
              borderWidth: 1,
              data: dataCumulative,
              fill: false,
              pointRadius: 1,
              pointHoverRadius: 2,
              yAxisID: 'y-axis-1',
          },
          {
              type: 'bar',
              label: 'New deaths',
              backgroundColor: 'lightblue',
              borderColor: 'lightblue',
              borderWidth: 0,
              data: dataDeltas,
              yAxisID: 'y-axis-2',
          },
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
        text: title,
      },
      tooltips: {
        mode: 'index',
        intersect: false,
        position: 'nearest',
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

document.getElementById('toggleZoomDeaths').addEventListener('click', function() {
    deathsChart.options.title.text = deathsChart.options.title.text == title ? title30 : title;
    deathsChart.data.labels = deathsChart.data.labels.length == 30 ? labels : labels.slice( -30 );
    deathsChart.data.datasets[0].data = deathsChart.data.datasets[0].data.length == 30 ? dataCumulative : dataCumulative.slice( -30 );
    deathsChart.data.datasets[1].data = deathsChart.data.datasets[1].data.length == 30 ? dataDeltas : dataDeltas.slice( -30 );
    deathsChart.update( { duration: 0 } );
 });

</script>

    </div>
    
    <!-- <div class="tab-pane fade" id="testsgraph" role="tabpanel" aria-labelledby="tests-graph-tab">
      <p>Coming soon - daily/cumulative tests</p>
    </div> -->    
</div>

<hr width="75%" />

<p><small>Note: The spike on 15 June 2020 is due to the inclusion of results from the UK Gov testing programme.
Prior to this date, figures only include those tested through NHS labs.</small></p>

<p><small>Data is extracted automatically from the <a href='$source_page'>Scottish Government website</a>. The source site is updated daily at 14:00 UK time and this site updates at 14:05.</small></p>
</div>

HTML

say <<'HTML';
    <!-- Bootstrap -->
    <script src="https://code.jquery.com/jquery-3.5.1.slim.min.js" integrity="sha384-DfXdz2htPH0lsSSs5nCTpuj/zy4C+OGpamoFVy38MVBnE+IbbVYUew+OrCXaRkfj" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/popper.js@1.16.1/dist/umd/popper.min.js" integrity="sha384-9/reFTGAW83EW2RDu2S0VKaIzap3H66lZH81PoYlFhbGU+6BZp6G7niu735Sk7lN" crossorigin="anonymous"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js" integrity="sha384-B4gt1jrGC7Jh4AgTPSdUtOBvfO8shuf57BaghqFfPlYxofvL8/KUEfYiJOMMV+rV" crossorigin="anonymous"></script>
  </body>
</html>
HTML
