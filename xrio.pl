#!/usr/bin/perl -w

use strict;

use Cwd 'chdir';
use File::Basename;
use Tk;
use Tk::BrowseEntry;
use Tk::Dialog;
use Tk::DirTree;
use Tk::FBox;
use Tk::LabFrame;
use Tk::ProgressBar;
use Tk::Radiobutton;
use Tk::TList;

local *RIO;
use vars qw($MW $Host $Device $DeviceStat
            $status
            $HList @Hcontents %Hsize %Hindex @Hraw_contents
            $DList @Dcontents %Dsize

            $Hsort $Hreverse $Hshowall $Hsel
            $DTotal $DUsed $DRemain $Dne
               $memory $device
            $STotal $SUsed $SRemain

            $path

            $SysD $Snowblind
            );

$SysD		= '[http://sysdlabs.hypermart.net]';
$Snowblind	= '[http://www.world.co.uk/sba/index.htm]';

my $path = shift @ARGV;
$path = Cwd::getcwd () if (!defined ($path) || !-d $path);

my %listopt = (-background		=> 'white',
               -selectforeground	=> 'white',
               -selectbackground	=> 'darkblue',
               -scrollbars		=> 'se');

my $fontf12	= '-*-fixed-*-*-*-*-*-120-*-*-*-*-*-*';
my $fontf14	= '-*-fixed-*-*-*-*-*-140-*-*-*-*-*-*';
my $buttwidth	= 12;

$MW = MainWindow->new ();
$MW->title ('X11 FrontEnd for Rio Utility');
$MW->resizable (0, 0);

my $Menubar = $MW->Frame->
grid (-row => 1, -column => 1, -columnspan => 2, -sticky => 'ew');
$Menubar->gridColumnconfigure (0, -weight => 1);

$Host	= $MW->LabFrame (-label => 'Host',	-labelside => 'acrosstop')->
grid (-row => 2, -column => 1, -sticky => 'snw');
$Device	= $MW->LabFrame (-label => 'Device',	-labelside => 'acrosstop')->
grid (-row => 2, -column => 2, -sticky => 'snw');
$DeviceStat = $MW->Frame->
grid (-row => 3, -column => 1, -columnspan => 2, -sticky => 'nw');

$STotal		= $DeviceStat->Label;
$SUsed		= $DeviceStat->Label;
$SRemain	= $DeviceStat->Label;

$status		= $MW->Label (-text		=> 'Select some files',
                              -font		=> $fontf14,
                              -foreground	=> 'black');


###############################################################################
# "Globals"
###############################################################################
$Hsort		= 'Filename';
$Hreverse	= 0;
$Hshowall	= 0;
$Hsel		= 0;

$DTotal		= 0;
$DUsed		= 0;
$DRemain	= 0;
$Dne		= 0;

$memory		= '';
$device		= '0x378';

my $open_browsr	= 0;
my $open_copy	= 0;
###############################################################################


$MW->protocol ('WM_DELETE_WINDOW' => my $MW_Quit = sub {
   if (!$open_browsr && !$open_copy) {
      $MW->destroy ();
      exit;
   }
});


###############################################################################
# Menu Frame
###############################################################################
$Menubar->Menubutton (qw/-text File -tearoff 0 -menuitems/ =>
    [
     [Button    => '~Quit', -command => \&$MW_Quit]
    ]
)->grid (-sticky => 'nw');
$Menubar->Menubutton (qw/-text Help -tearoff 0 -menuitems/ =>
    [
     [Button    => '~About', -command => \&About],
    ]
)->grid (-row => 0, -column => 1, -sticky => 'nw');


###############################################################################
# Host Frame
###############################################################################
my $HfilesC0_frame	= $Host->Frame->pack (-anchor	=> 'nw', -fill => 'x');
my $HfilesC1_frame	= $Host->Frame->pack (-anchor	=> 'nw', -fill => 'x');
my $HfilesB_frame	= $Host->Frame->pack (-anchor	=> 'se', -side => 'bottom');
my $Hfiles_frame	= $Host->Frame->pack (-anchor	=> 'sw', -side => 'bottom');

my $HList = $Hfiles_frame->Scrolled ('TList',
                                     -width		=> 60,
                                     -height		=> 20,
                                     -font		=> $fontf12,
                                     -orient		=> 'horizontal',
                                     -selectmode	=> 'extended',
                                     %listopt
)->
pack (-expand => 'yes', -fill => 'both');


&HostScan ($path = Cwd::abs_path ($path));
$HList->configure (-browsecmd => \&StatusRefr);


my $location = $HfilesC0_frame->Label (-text => &truncate ($path, 50))->
pack (-side => 'left');

$HfilesC0_frame->Button (-text => 'Browse',
-command => sub {
   return if ($open_browsr);

   my $Browse = MainWindow->new ();
   $Browse->protocol ('WM_DELETE_WINDOW' => my $Quit = sub {
      $Browse->destroy ();
      $open_browsr = 0;
   });

   $Browse->title ('MP3 Browser');
   $open_browsr = 1;

   $Browse->Label (-text => 'Double-click to open:')->
   pack (-anchor => 'nw');

   my $Open = sub {
      $path = shift;
      $path =~ s#^/{2}#/#;
      &HostScan ($path);

      $location->configure (-text	=> &truncate ($path, 50));
      $status->configure (-text		=> "Open $path",
                          -foreground	=> 'black');
   };

   $Browse->Scrolled ('DirTree',
                      -width		=> 40,
                      -height		=> 20,
                      -showhidden	=> 1,
                      -directory	=> $path,
                      -command		=> sub { $Open->(shift) },
                      %listopt)->
   pack (-anchor => 'nw', -fill => 'both', -expand => 'yes');

   $Browse->Button (-text => 'Open playlist',
   -command => sub {
      my $tpath = $MW->FBox (-filetypes	=> [['M3U Playlists',	'.m3u'],
                                           ['Text files',	'.txt'],
                                           ['All files',	'*']])
      ->Show;

      $Open->($tpath) if (defined ($tpath));
   })->
   pack (-side => 'left');

   $Browse->Button (-text => 'Quit', -command => \&$Quit)->
   pack (-anchor => 'se');
})->
pack (-side => 'right');


$HfilesC1_frame->Radiobutton (-text	=> 'MP3 files',
                              -variable	=> \$Hshowall,
                              -value	=> 0,
-command => sub {
   &HostScan ($path);
   $status->configure (-text		=> 'Show MP3 files only',
                       -foreground	=> 'black');
})->
pack (-side => 'left');

$HfilesC1_frame->Radiobutton (-text	=> 'All files',
                              -variable	=> \$Hshowall,
                              -value	=> 1,
-command => sub {
   &HostScan ($path);
   $status->configure (-text		=> 'Show all files',
                       -foreground	=> 'black');
})->
pack (-side => 'left');

$HfilesC1_frame->Checkbutton (-text	=> 'Reverse',
                              -variable	=> \$Hreverse,
                              -onvalue	=> 1,
                              -offvalue	=> 0,
                              -command	=> sub { &HostRefresh (@Hcontents) }
)->
pack (-side => 'right');

$HfilesC1_frame->BrowseEntry (-label		=> 'Sort by:',
                              -choices		=> ['Filename',
                                                    'Size',
                                                    'Access Time',
                                                    'Modify Time',
                                                    'Change Time',
                                                    'Nothing'],
                              -variable		=> \$Hsort,
                              -state		=> 'readonly',
                              -width		=> 12,
                              -browsecmd	=> sub { &HostRefresh (@Hcontents) }
)->
pack (-side => 'right');

$HfilesB_frame->Button (-text	=> 'Inverse sel.',
                        -font	=> $fontf12,
                        -width	=> $buttwidth,
-command => sub {
   my $i;
   for ($i = 0; $i < scalar @Hcontents; $i++) {
      if ($HList->selectionIncludes ($i)) {
         $HList->selectionClear ($i);
      } else {
         $HList->selectionSet ($i);
      }
   }

   &StatusRefr;
})->
pack (-side => 'left');

$HfilesB_frame->Button (-text	=> 'Delete',
                        -font	=> $fontf12,
                        -width	=> $buttwidth,
-command => sub {
   if (-f $path) {
      $MW->Dialog (-title		=> 'Error',
                   -text		=> "Can't manipulate files on playlist!",
                   -bitmap		=> 'error',
                   -default_button	=> 'OK',
                   -buttons		=> ['OK']
      )->Show;
      return;
   }

   my $n = &Delete (sub { unlink (shift) }, @Hcontents[$HList->info ('selection')]);

   &HostScan ($path);
   $status->configure (-text		=> "Deleted $n file(s) from host",
                       -foreground	=> 'black');
})->
pack (-side => 'left');

$HfilesB_frame->Button (-text	=> 'Rescan',
                        -font	=> $fontf12,
                        -width	=> $buttwidth,
-command => sub {
   &HostScan ($path);
   $status->configure (-text		=> "Rescaned $path",
                       -foreground	=> 'black');
})->
pack (-side => 'left');

$HfilesB_frame->Button (-text	=> '>>',
                        -font	=> $fontf12,
                        -width	=> $buttwidth,
-command => sub {
   unless ($Hsel <= $DRemain) {
      $MW->Dialog (-title		=> 'Error',
                   -text		=> 'Insufficient target space!',
                   -bitmap		=> 'error',
                   -default_button	=> 'OK',
                   -buttons		=> ['OK']
      )->Show;
      return;
   }
   &Copy ('-u', \%Hsize, @Hcontents[$HList->info ('selection')]);
})->
pack (-side => 'left');
###############################################################################


###############################################################################
# Device Frame
###############################################################################
my $DfilesC0_frame	= $Device->Frame->pack (-anchor	=> 'nw', -fill => 'x');
my $DfilesC1_frame	= $Device->Frame->pack (-anchor	=> 'nw', -fill => 'x');
my $DfilesB_frame	= $Device->Frame->pack (-anchor	=> 'sw', -side => 'bottom');
my $Dfiles_frame	= $Device->Frame->pack (-anchor	=> 'sw', -side => 'bottom');

my $DList = $Dfiles_frame->Scrolled ('TList',
                                     -width		=> 60,
                                     -height		=> 20,
                                     -font		=> $fontf12,
                                     -orient		=> 'horizontal',
                                     -selectmode	=> 'extended',
                                     %listopt
)->
pack (-expand => 'yes', -fill => 'both');


&DeviceScan;


$DfilesC0_frame->Label (-text => 'Memory: ')->
pack (-side => 'left');

$DfilesC0_frame->Radiobutton (-text	=> 'Internal',
                             -variable	=> \$memory,
                             -value	=> '',
-command => sub {
   &DeviceScan &&
   $status->configure (-text		=> 'Operating on internal memory',
                       -foreground	=> 'black');
})->
pack (-side => 'left');

$DfilesC0_frame->Radiobutton (-text	=> 'External',
                             -variable	=> \$memory,
                             -value	=> '-x',
-command => sub {
   &DeviceScan &&
   $status->configure (-text		=> 'Operating on extended memory',
                       -foreground	=> 'black');
})->
pack (-side => 'left');

$DfilesC0_frame->BrowseEntry (-label		=> 'Device at (port):',
                             -choices		=> [qw(0x278 0x378)],
                             -variable		=> \$device,
                             -state		=> 'readonly',
                             -width		=> 10,
-browsecmd => sub {
   &DeviceScan &&
   $status->configure (-text		=> "Device at $device",
                       -foreground	=> 'black');
})->
pack (-side => 'right');


$DfilesC1_frame->Button (-text		=> 'Clean',
                         -width		=> 15,
-command => sub {
   my $button = $MW->Dialog (-title		=> 'Warning!',
                             -text		=> 'Are you sure that you want'.
                                                   ' to delete ALL data from device?',
                             -bitmap		=> 'question',
                             -buttons		=> ['Yes', 'No'],
                             -default_button	=> 'No'
   )->Show;

   if ($button eq 'Yes') {
      &openRIO ('-za');
      &closeRIO ();

      &DeviceScan &&
      $status->configure (-text		=> "Erased all data from device",
                          -foreground	=> 'black');
   }
})->
grid (-row => 1, -column => 1);

$DfilesC1_frame->Button (-text		=> 'Initialize',
                         -width		=> 15,
-command => sub {
   my $button = $MW->Dialog (-title		=> 'Warning!',
                             -text		=> 'Are you sure that you want'.
                                                   ' to delete ALL data from device?',
                             -bitmap		=> 'question',
                             -buttons		=> ['Yes', 'No'],
                             -default_button	=> 'No'
   )->Show;

   if ($button eq 'Yes') {
      &openRIO ('-in');
      &closeRIO ();

      &DeviceScan &&
      $status->configure (-text		=> "Initialized device",
                          -foreground	=> 'black');
   }
})->
grid (-row => 1, -column => 2);


$DfilesB_frame->Button (-text	=> '<<',
                        -font	=> $fontf12,
                        -width	=> $buttwidth,
-command => sub {
   if (-f $path) {
      $MW->Dialog (-title		=> 'Warning!',
                   -text		=> "You can't download files into playlist!".
                                           " All files you try to download will stay".
                                           " at playlist's directory!",
                   -bitmap		=> 'error',
                   -default_button	=> 'OK',
                   -buttons		=> ['OK']
      )->Show;
   };

   &Copy ('-g', \%Dsize, @Dcontents[$DList->info ('selection')]);
})->
pack (-side => 'left');

$DfilesB_frame->Button (-text	=> 'Rescan',
                        -font	=> $fontf12,
                        -width	=> $buttwidth,
-command => sub {
   &DeviceScan &&
   $status->configure (-text		=> 'Rescanned device',
                       -foreground	=> 'black');
})->
pack (-side => 'left');

$DfilesB_frame->Button (-text	=> 'Delete',
                        -font	=> $fontf12,
                        -width	=> $buttwidth,
-command => sub {
   my $n = &Delete (sub {
      my $name = shift;
      &openRIO ("-z \"$name\"");
      &closeRIO;
   }, @Dcontents[$DList->info ('selection')]);

   $n &&
   $status->configure (-text		=> "Deleted $n file(s) from device",
                       -foreground	=> 'black');
   &DeviceScan;
})->
pack (-side => 'left');

$DfilesB_frame->Button (-text	=> 'Inverse sel.',
                        -font	=> $fontf12,
                        -width	=> $buttwidth,
-command => sub {
   my $i;
   for ($i = 0; $i < scalar @Dcontents; $i++) {
      if ($DList->selectionIncludes ($i)) {
         $DList->selectionClear ($i);
      } else {
         $DList->selectionSet ($i);
      }
   }
})->
pack (-side => 'left');
###############################################################################


$DeviceStat->Label (-text => 'Total device space:')->
grid (-row => 1, -column => 1, -sticky => 'nw');
$STotal->grid (-row => 1, -column => 2, -sticky => 'ne');

$DeviceStat->Label (-text => 'Used device space:')->
grid (-row => 2, -column => 1, -sticky => 'nw');
$SUsed->grid (-row => 2, -column => 2, -sticky => 'ne');

$DeviceStat->Label (-text => 'Remain device space:')->
grid (-row => 3, -column => 1, -sticky => 'nw');
$SRemain->grid (-row => 3, -column => 2, -sticky => 'ne');

$status->
grid (-row => 5, -column => 1, -columnspan => 2, -sticky => 'nw');


Tk::MainLoop ();
exit;


sub HostScan  {
   $path = shift;

   $HList->selectionClear ();
   @Hraw_contents	= ();
   %Hsize		= ();

   if (-f $path) {
      chdir (dirname ($path))	|| die "Playlist processing error: $!\n";
      open (PLAYLIST, $path)	|| die "Playlist processing error: $!\n";
      while (<PLAYLIST>) {
         s#\s*$##;

         s#\\#/#g;
         push (@Hraw_contents, $_);
         $Hsize{$_} = (stat ($_))[7];
      }
      close (PLAYLIST);

      $Hsort	= 'Nothing';
      $Hreverse	= 0;
      $HList->configure (-background => 'grey');
   } elsif (-d $path) {
      chdir ($path)		|| die "Directory processing error: $!\n";
      $path = Cwd::getcwd ();

      opendir (DIR, $path);
      foreach (readdir (DIR)) {
         next if (m#^\.{1,2}$# || (!$Hshowall && !m#\.MP3$#i) || !-f $_);

         push (@Hraw_contents, $_);
         $Hsize{$_} = (stat ($_))[7];
      }
      closedir (DIR);

      $HList->configure (-background => 'white');
   }

   &HostRefresh (@Hraw_contents);
}

sub HostRefresh {
   my @buffer = @_;
   my @oindex = @Hcontents[$HList->info ('selection')];

   unless ($Hsort =~ /^NOTHING$/i) {
      @buffer = sort {
         if (!defined ($Hsize{$b})) {
            return -1;
         } elsif (!defined ($Hsize{$a})) {
            return 1;
         }

         my $s;
         if ($Hsort =~ /^FILENAME$/i) {
            $s = lc (basename ($a)) cmp lc (basename ($b));
         } elsif ($Hsort =~ /^SIZE$/i) {
            ($s = $Hsize{$b} <=> $Hsize{$a}) ||
            ($s = lc $a cmp lc $b);
         } elsif ($Hsort =~ /^A\w+ TIME$/i) {
            ($s = (stat ($a))[9] <=> (stat ($b))[9]) ||
            ($s = lc $a cmp lc $b);
         } elsif ($Hsort =~ /^M\w+ TIME$/i) {
            ($s = (stat ($a))[8] <=> (stat ($b))[8]) ||
            ($s = lc $a cmp lc $b);
         } elsif ($Hsort =~ /^C\w+ TIME$/i) {
            ($s = (stat ($a))[10] <=> (stat ($b))[10]) ||
            ($s = lc $a cmp lc $b);
         }

         return $s;
      } @buffer;
   } else {
      @buffer = @Hraw_contents;
   }

   $HList->delete (0, scalar @Hcontents);
   @Hcontents	= ();
   %Hindex	= ();
   my $i	= 0;

   foreach ($Hreverse ? reverse (@buffer) : @buffer) {
      push (@Hcontents, $_);
      $Hindex{$_} = $i++;

      $HList->insert ('end',
                      -itemtype	=> 'text',
                      -text	=> sprintf ('%-47s %10s',
				&truncate (basename ($_), 47),
				defined ($Hsize{$_}) ? &sizestr ($Hsize{$_}) : ''));
   }

   foreach (@oindex) {
      $HList->selectionSet ($Hindex{$_});
   }
}

sub StatusRefr {
   $Hsel = 0;
   my @sel = $HList->info ('selection');
   map ($Hsel += defined ($_) ? $_ : 0, @Hsize {@Hcontents[@sel]});
   my $left = $DRemain - $Hsel;

   $status->configure (-text		=> sprintf
                                  ('Selected %3d files containing %10s at host (left %10s)',
                                   scalar @sel,
                                   &sizestr ($Hsel),
                                   ($left > 0) ? &sizestr ($left) : 'nothing!!!'),
                       -foreground	=> ($left >= 0) ? 'black' : 'red');
}


sub DeviceScan {
   $DList->delete (0, scalar @Dcontents);
   $DList->selectionClear ();
   @Dcontents	= ();
   %Dsize	= ();

   &openRIO ('-d');
   my @rio = <RIO>;
   unless (&closeRIO) {
      $DTotal = $DUsed = $DRemain = 0;
      $STotal	->configure (-text => '?'x3);
      $SUsed	->configure (-text => '?'x3);
      $SRemain	->configure (-text => '?'x3);
      return 0;
   }

   shift @rio;
   $Dne		= (shift (@rio) =~ m#:\s(.*)$#)[0];
   $DTotal	= (shift (@rio) =~ m#:\s(.*?)\s#)[0] * 1024;
   $DUsed	= (shift (@rio) =~ m#:\s(.*?)\s#)[0] * 1024;
   $DRemain	= $DTotal - $DUsed;

   $STotal	->configure (-text => &sizestr ($DTotal));
   $SUsed	->configure (-text => &sizestr ($DUsed));
   $SRemain	->configure (-text => &sizestr ($DRemain));

   my (@buffer, $size, $bitrate, $freq, $date, $time, $name);
   my $flag	= 0;
   my $i	= 0;

   if ($Dne) {
      foreach (@rio) {
         if ($flag) {
            ($size, $bitrate, $freq, $date, $time, $name) =
                    (m#\s(\d+?)\s+(\d+)\s+(\d+)\s+(.*?)\s(.*?)\s(.*?)\s*$#);

            push (@Dcontents, $name);
            $Dsize{$name} = $size;

            $DList->insert ('end',
                            -itemtype	=> 'text',
                            -text	=> sprintf
             ('%2d. %-43s %10s  %18s  [%s %s]',
              ++$i, &truncate ($name, 43), &sizestr ($size),
              ($bitrate > 360) ? 'Not MP3' : sprintf ("%3d Kbps %5d KHz", $bitrate, $freq),
              $date, $time
              )
            );
         } else {
            $flag = 1 if (m#^\-+$#);
         }
      }
   }

   return 1;
};


sub openRIO {
   unless (open (RIO, "rio -p $device $memory ". join (' ', @_).'|')) {
      print '*'x30, "\n",
            "Rio Utility not found!!!\n",
            "Sorry, XRio can't run without Rio Utility;\n",
            "it's just a frontend for Rio Utility.\n",
            "Please get Rio Utility at\n",
            $Snowblind, "\n",
            "or\n",
            $SysD, "\n",
            '*'x30, "\n";
      exit -1;
   } else {
      return 1;
   }
}

sub closeRIO {
   if (close (RIO)) {
      unless ($memory) {
         $status->configure (-text		=> "Rio not connected at $device!",
                             -foreground	=> 'red');
      } else {
         $status->configure (-text		=> "Extended memory not present at $device!",
                             -foreground	=> 'red');
      }

      return 0;
   } else {
      return 1;
   }
}


sub Delete {
   my $killer	= shift;
   my @files	= @_;

   my $button;
   my $d_all	= 0;
   my $i	= 0;

   if (@files) {
      foreach (@files) {
         unless ($d_all) {
            $button =
            $MW->Dialog (-title		=> 'Deleting file '.($i + 1).' of '.scalar @files,
                         -text		=> 'Are you sure that'.
                                           ' you want to delete file ['.basename ($_).']?',
                         -bitmap	=> 'question',
                         -buttons	=> ['Yes', 'No', 'All', 'Cancel'],
                         -default_button=> 'No'
            )->Show;
         }

         $d_all = 1 if ($button eq 'All');

         if ($button eq 'Yes' || $d_all) {
            unless ($killer->($_)) {
               $MW->Dialog (-title	=> 'Error deleting file '.($i + 1).
                                           ' of '.scalar @files,
                            -text	=> 'Error deleting file ['.basename($_).']!',
                            -bitmap	=> 'error',
		            -buttons	=> ['OK'],
                            -default_button	=> 'OK'
               )->Show;
            } else {
               $i++;
            }
         } elsif ($button eq 'No') {
            next;
         } else {
            last;
         }
      }
   } else {
      $MW->Dialog (-title		=> 'Error',
                   -text		=> 'Must select some files to delete!',
                   -bitmap		=> 'error',
                   -default_button	=> 'OK',
                   -buttons		=> ['OK']
      )->Show;
   }

   return $i;
}

sub Copy {
   my $flag	= shift;
   my $size	= shift;
   my @list;

   if ($flag eq '-u') {
      @list = grep (-f, @_);
   } else {
      @list = @_;
   }

   unless (@list) {
      $MW->Dialog (-title		=> 'Error',
                   -text		=> 'Must select some files to transfer!',
                   -bitmap		=> 'error',
                   -default_button	=> 'OK',
                   -buttons		=> ['OK']
      )->Show;
      return;
   }

   foreach (@list) {
      if ((($flag eq '-g') && $Hsize{$_}) || (($flag eq '-u') && $Dsize{$_})) {
         $MW->Dialog (-title		=> 'Warning!',
                      -text		=> basename ($_).' already exists at target!',
                      -bitmap		=> 'error',
                      -default_button	=> 'OK',
                      -buttons		=> ['OK']
         )->Show;
         return;
      }
   }


   $MW->Busy (-recurse => 1);
   my %popt = (-width		=> 300,
               -height		=> 30,
               -borderwidth	=> 2,
               -relief		=> 'sunken',
               -from		=> 0,
               -to		=> 100,
               -blocks		=> 20,
               -colors		=> [qw(0	red
                                       15	yellow
                                       40	green)],
               -padx		=> 1,
               -pady		=> 1,
               -anchor		=> 'e');

   my $currentP	= 0;
   my $totalP	= 0;

   my $Copy = MainWindow->new ();
   $open_copy = 1;
   $Copy->resizable (0, 0);

   my $Transfer = $Copy->Label->
   grid (-row => 1, -column => 1, -columnspan => 2, -sticky => 'nw');

   my $Times = $Copy->Frame->
   grid (-row => 2, -column => 1, -columnspan => 2, -sticky => 'nw');
   $Times->Label (-text => 'Elapsed time:')->
   grid (-row => 1, -column => 1, -sticky => 'nw');
   my $Elapsed = $Times->Label (-text => '00:00')->
   grid (-row => 1, -column => 2, -sticky => 'ne');
   $Times->Label (-text => 'Remaining time:')->
   grid (-row => 2, -column => 1, -sticky => 'nw');
   my $Remaining = $Times->Label (-text => '??:??')->
   grid (-row => 2, -column => 2, -sticky => 'ne');


   $Copy->Label (-text => 'Current file:')->
   grid (-row => 3, -column => 1, -sticky => 'nw');
   $Copy->ProgressBar (-variable => \$currentP, %popt)->
   grid (-row => 3, -column => 2);
   my $CurrentPInd = $Copy->Label (-width => 6)->
   grid (-row => 3, -column => 3);

   $Copy->Label (-text => 'Total:')->
   grid (-row => 4, -column => 1, -sticky => 'nw');
   $Copy->ProgressBar (-variable => \$totalP, %popt)->
   grid (-row => 4, -column => 2);
   my $TotalPInd = $Copy->Label (-width => 6)->
   grid (-row => 4, -column => 3);


   my $name;

   my $total = 0;
   map ($total += $_, @{$size} {@list});

   my $copied		= 0;
   my $copied_total	= 0;
   my $copied_now	= 0;

   my ($blocks, $curr_block, $remain_blocks);
   my $started		= time ();
   my $elapsed		= 0;
   my $remaining	= 0;

   my $i = 0;

   my $child_pid;
   my $Destroyler = sub {
      kill ('TERM', $child_pid);
      wait ();
      close (CHILD);

      $copied_total = $copied_now if (scalar @list ==  $i);
      $status->configure (-text => sprintf
                                    ('Copied %s in %d file(s) during %02d:%02d',
                                     &sizestr ($copied_total),
                                     $i,
                                     int ($elapsed/60), $elapsed % 60));

      ($flag eq '-g') && &HostScan ($path);
      ($flag eq '-u') && &DeviceScan ();

      $Copy->destroy ();
      $MW->Unbusy ();

      $open_copy = 0;
   };

   $Copy->protocol ('WM_DELETE_WINDOW' => sub {
      (($flag eq '-g') && unlink ($name)); $i--;
      $Destroyler->();
   });
   $Copy->Button (-text => 'Cancel', -command => sub {
      (($flag eq '-g') && unlink ($name)); $i--;
      $Destroyler->();
   })->
   grid (-row => 5, -column => 1, -columnspan => 3);


   $SIG{'NUM60'}	= \&$Destroyler;
   my $await		= 0;
   $SIG{'NUM61'}	= sub { $await++ };
   my $next		= 0;
   $SIG{'NUM62'}	= sub { $next = 1 };


   if (!defined ($child_pid = open (CHILD, '-|'))) {
      die "Can't fork(): $!\n";
   } elsif (!$child_pid) {
      my $parent_pid = getppid ();
      $/ = "\r";

      foreach $name (@list) {
         &openRIO ('-v', $flag, "\"$name\"");
         while (<RIO>) {
            if (m#\s(\d+)\s*$#) {
               print $1, "\n";
               kill ('NUM61', $parent_pid);
            }
         }
         &closeRIO () || goto EXIT;

         kill ('NUM62', $parent_pid);
      }

EXIT:
      kill ('NUM60', $parent_pid);
      while (1) { sleep (10) };
   }

   $Copy->repeat (100 => sub {
      if ($await) {
         $elapsed = time () - $started;
         chomp ($curr_block = <CHILD>);

         if (!$i || $next) {
            $name		= $list[$i++];
            $blocks		= $curr_block;
            $copied_total	= $copied_now;
            $copied		= 0;

            $Copy->title (sprintf
                 ('Copying %s (%s), file %d of %d',
                  basename ($name), &sizestr (${$size}{$name}), $i, scalar @list));

            $next = 0;
         }

         $remain_blocks	= $blocks - $curr_block;

         $copied	+= 32*1024;
         $copied_now	= $copied_total + $copied;

         $Transfer->configure (-text => sprintf
                  ('%s %s of %s at %s/s',
                   (($flag eq '-g') && 'Downloaded') ||
                   (($flag eq '-u') && 'Uploaded'),
                   &sizestr ($copied_now),
                   &sizestr ($total),
                   &sizestr (($elapsed) ? ($copied_now/$elapsed) : 0)));
         $CurrentPInd->configure (-text => sprintf
                  ('%1.01f%%', $currentP = ($copied*100/${$size}{$name})));
         $TotalPInd->configure (-text => sprintf
		  ('%1.01f%%', $totalP	= ($copied_now*100/$total)));
         $Elapsed->configure (-text => sprintf
		  ('%02d:%02d', int ($elapsed/60), $elapsed % 60));

         if ($copied_now) {
            $remaining = $elapsed*$total/($copied_now) - $elapsed;
            $Remaining->configure (-text => sprintf
                  ('%02d:%02d', int ($remaining/60), $remaining % 60));
         }

         $await--;
      }
   });
}


sub truncate {
   my $name	= shift;
   my $flength	= shift;
   return (length ($name) > $flength) ? substr ($name, 0, $flength - 3).'...' : $name;
}

sub sizestr {
   my $size = shift;
   my $unit = ' bytes';

   if ($size >= 2**20) {
      $size/=2**20;
      $unit = 'MB';
   } elsif ($size >= 2**10) {
      $size/=2**10;
      $unit = 'KB';
   }

   my ($main, $rest) = split (m#\.#, sprintf ('%01.02f', $size));
   $rest =~ s#0+$##;
   $main .= ".$rest" if ($rest);

   return $main.$unit;
}

sub About {
   my $About = MainWindow->new ();
   $About->title ('About XRio');
   $About->Button (-text => 'Close', -command => [destroy => $About])->
   pack (-side => 'bottom');

   $About->Label (-text => 'XRio v0.1a', -font => $fontf14)->pack ();
   $About->Label (-text => "Perl script coded by Stas,\n".
                           "(C)opyLeft by SysD Destructive Labs, 1997-1999\n",
                  -font => $fontf12)->pack ();

   $About->Label (-text => "This program is a X11 FrontEnd to \"Rio Utility\"\n".
                           "by The Snowblind Alliance. It provides easy and practical\n".
                           "access to Rio MP3 Player by Diamond on UN*X systems\n".
                           "(like Linux and FreeBSD). I hope, that XRio interface is\n".
                           "self-explanatory; anyway, soon I think I gonna write detailed\n".
                           "help page for it...\n".
                           "You can find this program at SysD Labs' official page:\n".
                           "$SysD\n".
                           "You may found patched Rio Utility there, but\n".
                           "The Snowblind Alliance's official page is:\n".
                           "$Snowblind\n".
                           "\nEnjoy RIO on your favourite OS!!!!\n\n".
                           "P.S. - Please, DO NOT try to run XRio on Win32!!!\n".
                           "Visit SysD Labs page to see reasons why!\n".
                           "It's NOT a Window\$-hate joke!"
                           ,
                  -justify => 'left'
                  )->pack (side => 'left');
}
