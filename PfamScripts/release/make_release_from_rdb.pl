#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Compress::Zlib;
use File::Copy;
use Cwd;
use LWP::UserAgent;
use Log::Log4perl qw(:easy);
use DateTime;
use File::Touch;
use DDP;

use Bio::Pfam::Config;
use Bio::Pfam::PfamJobsDBManager;
use Bio::Pfam::PfamLiveDBManager;

#Start up the logger
Log::Log4perl->easy_init($DEBUG);
my $logger = get_logger();

my $config = Bio::Pfam::Config->new;

my ( $help, $newRelease, $oldRelease, $relDir, $updateDir );

GetOptions(
  "new=s"    => \$newRelease,
  "old=s"    => \$oldRelease,
  "relDir=s" => \$relDir,
  "upDir=s"  => \$updateDir,
  "h"        => \$help
);

if ( !$newRelease || !$oldRelease ) {
  &help;
}

if ($relDir) {
  unless ( -d $relDir ) {
    die "Could not find the update dir\n";
  }
}
else {
  $relDir = '.';
}

unless ( $updateDir and -d $updateDir ) {
  $logger->logdie("Please specify an update directory.\n");
}

#This takes the input release numbers and checks that the are sensible.
#If they are, then it make the release directory.
$logger->info("Checking release numbers");
my ( $major, $point, $old_major, $old_point ) =
  checkReleaseNumbers( $newRelease, $oldRelease );

$logger->info("Making release dir");
unless ( -e "$relDir/$major.$point" ) {
  mkdir("$relDir/$major.$point")
    or
    $logger->logdie("Could not make release directory $relDir/$major.$point");
}
my $thisRelDir = "$relDir/$major.$point";
$logger->info("Made $thisRelDir");

$logger->info("Making release log dir");
my $logDir = "$relDir/Logs";
unless ( -e $logDir ) {
  mkdir($logDir)
    or $logger->logdie("Could not make release directory $logDir");
}
$logger->info("Made $logDir");

#Can we connect to the PfamLive database?
$logger->info("Going to connect to the live database\n");

my $pfamDB = Bio::Pfam::PfamLiveDBManager->new( %{ $config->pfamliveAdmin } );
unless ($pfamDB) {
  Bio::Pfam::ViewProcess::mailPfam(
    "View process failed as we could not connect to pfamlive");
}

$logger->debug("Got pfamlive database connection");
my $dbh = $pfamDB->getSchema->storage->dbh;

my $jobsDB = Bio::Pfam::PfamJobsDBManager->new( %{ $config->pfamjobs } );
unless ($jobsDB) {
  Bio::Pfam::ViewProcess::mailPfam( "Failed to run view process",
    "Could not get connection to the pfam_jobs database" );
}

#Now make sure that all of the view processes have completed
my $noUnFinishedJobs = $jobsDB->getSchema->resultset('JobHistory')->search(
  {
    -and => [
      status   => { '!=', 'DONE' },
      status   => { '!=', 'KILL' },
      job_type => [qw(clan family)]
    ],
  }
);

if ( $noUnFinishedJobs != 0 ) {
  $logger->warn("There are currently $noUnFinishedJobs in the jobs database");

  if ( -e $logDir . "/overrideView" ) {

  }
  else {
    print STDERR "\nDo you want to continue [y/n]:";

    while (<STDIN>) {
      if (/y/i) {
        $logger->info("User confirmed all view processes are complete!");
        open( O, ">" . $logDir . "/overrideView" )
          or die "Could not open $logDir/overrideView:[$!]\n";
        close(O);
        last;
      }
      else {
        exit;
      }
    }
  }
}
else {
  $logger->info("All view processes are complete!");
}

my $version = $pfamDB->getSchema->resultset('Version')->search()->first;
if ( $version->pfam_release ne "$major.$point" ) {
  my $dt  = DateTime->now;
  my $ymd = $dt->ymd;

  my ( $sqV, $trV );
  open( V, $updateDir . "/reldate.txt" );
  while (<V>) {
    $sqV = $1 if (m|UniProtKB/Swiss-Prot Release (\S+)|);
    $trV = $1 if (m|UniProtKB/TrEMBL Release (\S+)|);
  }
  close(V);

  #Set the hmmer version
  my $hmmerVersion;
  open( V, $config->hmmer3bin . "/hmmsearch -h |" )
    or $logger->logdie("Failed to get help on hmmsearch");
  while (<V>) {
    if (/^# HMMER (\S+)/) {
      $hmmerVersion = $1;
      last;
    }
  }
  close(V);

  unless ($hmmerVersion) {
    $logger->logdie("Failed to detect hmmer version!");
  }

  $version->update(
    {
      pfam_release       => "$major.$point",
      pfam_release_date  => $ymd,
      hmmer_version      => $hmmerVersion,
      reference_proteome_version => $sqV, #RP version will be same as sprot version
      swiss_prot_version => $sqV,
      trembl_version     => $trV
    }
  );
}

#Get the latest userman.txt and relnotes.txt from the ftp site.
unless ( -s "$thisRelDir/relnotes.txt" and -s "$thisRelDir/userman.txt" ) {
  $logger->info(
    "Getting text files from $old_major.$old_point from the ftp site");
  getTxtFiles($thisRelDir);
}
$logger->info("Got relnotes and userman");

#Get the pfamseq files required for the release
# 1. pfamseq
# 2. sprot.dat
# 3. trembl.dat
# 4. genpept.fa
# 5. metaseq
# 6. ncbi

#Upto here......

my ( $numSeqs, $numRes );

unless ( -e "$logDir/checkedseqsize" ){
    if ( -e $logDir . "/pfamseqSize" ) {
     open( S, $logDir . "/pfamseqSize" )
      or $logger->logdie("Could not open $logDir./pfamseqSize:[$!]");
     while (<S>) {
      $numSeqs = $1 if (/sequences\: (\d+)/);
     $numRes  = $1 if (/residues\: (\d+)/);
     }
    close(S);
    $logger->info("Got pfamseq size (residues): $numSeqs, ($numRes)");
    }

    foreach my $f (qw(pfamseq uniprot uniprot_reference_proteomes.dat uniprot_sprot.dat uniprot_trembl.dat metaseq ncbi)) {
     unless ( -s "$thisRelDir/$f.gz" ) {
      if ( $f eq 'pfamseq' ) {
       ( $numSeqs, $numRes ) = checkPfamseqSize( $updateDir, $pfamDB );
          open( N, ">" . $logDir . "/pfamseqSize" )
           or die "Could not open $logDir/pfamseqSize:[$!]";
         print N "sequences: $numSeqs\n";
         print N "residues: $numRes\n";
          close(N);

     }
     $logger->info("Fetching the the sequence files");
     getPfamseqFiles( $thisRelDir, $updateDir, $config );
     }
    }

    touch("$logDir/checkedseqsize");
}

unless ( -s "$thisRelDir/Pfam-A.full" and -s "$thisRelDir/Pfam-A.seed" ) {
    makePfamAFlat( $thisRelDir, $pfamDB );
}

unless ( -e "$logDir/checkedA" ) {
  foreach my $f ( "$thisRelDir/Pfam-A.seed", "$thisRelDir/Pfam-A.full" ) {
    $logger->info("Checking format of $f");
    checkflat($f);
    touch("$logDir/checkedA");
  }
}


#Make the stats for the release

unless ( -s "$thisRelDir/stats.txt" ) {
  unless ( $numSeqs and $numRes ) {
    $logger->logdie(
      "Need to have the number of sequences and residues defined.\n");
  }
  makeStats( "$thisRelDir", $numSeqs, $numRes );
}
$logger->info("Made stats!");

#Make the indexes HMMs
unless ( -e "$logDir/checkedA.hmm" ) {
  foreach my $f (qw(Pfam-A.hmm)) {
    $logger->info("Checking HMM flatfile $f");
    my $version = $pfamDB->getSchema->resultset('Version')->search()->first;
    open( HMM,
          "checkhmmflat.pl -v -f $thisRelDir/$f -hmmer "
        . $version->hmmer_version
        . "|" )
      or $logger->logdie( "Could not run checkhmmfalt.pl -v -file $f -hmmer "
        . $version->hmmer_version
        . "[$!]" );
    my $error;
    while (<HMM>) {
      $error = 1;
      $logger->warn("ERROR with format of $f:[$!]");
    }

    $logger->logdie("Error found in $f") if ($error);
    unless ( -s "$thisRelDir/$f.bin" ) {

      #Press and convert the files.
      $logger->debug("Making Pfam-A.hmm.bin");

      system( $config->hmmer3bin . "/hmmpress -f $thisRelDir/$f" )
        and $logger->logdie("Failed to run hmmpress:[$!]");

      system( $config->hmmer3bin
          . "/hmmconvert -b $thisRelDir/$f > $thisRelDir/$f.bin " )
        and $logger->logdie("Failed to run hmmconvert:[$!]");
    }

    unless ( -e "$thisRelDir/$f.2" ) {
      system( $config->hmmer3bin
          . "/hmmconvert -2 $thisRelDir/$f > $thisRelDir/$f.2 " )
        and $logger->logdie("Failed to run hmmconvert:[$!]");
    }
    open( L, ">$logDir/checkedA.hmm" )
      or $logger->logdie("Could not open $logDir/checkedA.hmm:[$!]\n");
    print L "Checked!";
    close(L);
    $logger->info("Checked $f and made $f.bin");
  }
}

#Make Pfam-A.scan.dat
unless ( -s "$thisRelDir/Pfam-A.hmm.dat" ) {
  $logger->info("Making Pfam-A.hmm.dat");
  &makePfamAScanFile( "$thisRelDir", $pfamDB );
}
$logger->info("Made Pfam-A.scan.dat");

unless ( -s "$thisRelDir/active_site.dat" ) {
  $logger->info("Making active_site.dat");
  &makeActiveSiteDat( "$thisRelDir", $pfamDB );
}
$logger->info("Made activesite.dat");

unless ( -s "$thisRelDir/Pfam-A.dead" ) {
  $logger->info("Making Pfam-A.dead.");
  system("make_pfamA_dead.pl > $thisRelDir/Pfam-A.dead")
    and $logger->logdir("Failed to make Pfam-A.dead:[$!]");
}
$logger->info("Made Pfam-A.dead.");

unless ( -s "$thisRelDir/diff" ) {
  $logger->info("Making diff file");
  my $archive = $config->archiveLoc;
  $archive .= "/$old_major.$old_point/diff.gz";
  system(
"make_diff.pl -file $archive -old_rel $old_major -new_rel $major > $thisRelDir/diff"
  ) and $logger->logdie("Could not run make_diff.pl:[$!]");
}
$logger->info("Made diff file.");

my $pwd = cwd;

#Index the fasta files!
my $f = 'Pfam-A.fasta';
  unless ( -s "$thisRelDir/$f.00.phr" or -s "$thisRelDir/$f.phr" ) {
    chdir("$thisRelDir")
      || $logger->logdie("Could not change into $thisRelDir:[$!]");
    $logger->info("Indexing $f (formatdb)");
    system("formatdb -p T -i $f")
      and $logger->logdie("Failed to index $f:[$!]");
    chdir("$pwd") || $logger->logdie("Could not change into $pwd:[$!]");
  }
  $logger->info("Indexed $f");

#Make the Pfam-C file......
unless ( -s "$thisRelDir/Pfam-C" ) {
  $logger->info("Making Pfam-C");
  chdir($thisRelDir) or $logger->logdie("Could not change to release dir:[$!]");
  system("make_pfamC.pl")
    and $logger->logdie("Failed to run make_pfamC.pl:[$!]");
  chdir($pwd);
}
$logger->info("Made Pfam-C");

unless ( -e "$logDir/updatedClans" ) {
  $logger->info("Updating clan information");
  $logger->info("Updating number if architectures");
  $dbh->do(
"UPDATE clan c SET number_archs = (SELECT COUNT(DISTINCT auto_architecture) FROM clan_architecture a  WHERE c.clan_acc=a.clan_acc);"
    )
    or $logger->logdie(
    "Error updating clan architecture counts: " . $dbh->errstr );
  $logger->info("Updating number of structures");
  $dbh->do(
"UPDATE clan c SET number_structures =( select count(DISTINCT pdb_id, chain) from pdb_pfamA_reg r, clan_membership m where m.clan_acc=c.clan_acc and m.pfamA_acc=r.pfamA_acc);"
    )
    or
    $logger->logdie( "Error updating clan structure counts: " . $dbh->errstr );
  open( L, ">$logDir/updatedClans" )
    or $logger->logdie("Could not open $logDir/updatedClans for writing.:[$!]");
  print L "Done\n";
  close(L);
}
$logger->info("Updated clans table");

#sections below hashed out as ncbi and metaseq tables don't exist so these can't be run
#unless ( -s "$thisRelDir/metaseq.stats" ) {
#  $logger->info("Caclculating metaseq coverage stats");
#  chdir("$thisRelDir")
#    or $logger->logdie("Could not chdir into $thisRelDir:[$!]");
#  system("calculate_coverage.pl -meta > metaseq.stats ")
#    and $logger->logdie("Could not run calculate coverage:[$!]");
#  chdir($pwd);
#}
#
#unless ( -s "$thisRelDir/ncbi.stats" ) {
#  $logger->info("Caclculating ncbi coverage stats");
#  chdir("$thisRelDir")
#    or $logger->logdie("Could not chdir into $thisRelDir:[$!]");
#  system("calculate_coverage.pl -ncbi > ncbi.stats ")
#    and $logger->logdie("Could not run calculate coverage:[$!]");
#  chdir($pwd);
#}

unless ( -e "$thisRelDir/PfamFamily.xml.gz" ) {
  $logger->info("Making site search xml");
  chdir("$thisRelDir")
    or $logger->logdie("Could not chdir into $thisRelDir:[$!]");

#TODO system("pfamSiteSearchXML.pl") and $logger->logdie("Could not run pfamSiteSearchXML.pl:[$!]");
  chdir($pwd);
}
$logger->info("Made site search xml");

unless ( -e "$thisRelDir/pdbmap" ) {
  $logger->info("Making pdbmap");

  my $stpdb= $dbh->prepare("select concat\(pdb_id, \";\"\), concat\(chain, \";\"\), concat\(pdb_res_start, pdb_start_icode, \"-\", pdb_res_end, pdb_end_icode, \";\"\), concat\(pfamA_id, \";\"\), concat\(a.pfamA_acc, \";\"\), concat\(pfamseq_acc, \";\"\), concat\(seq_start, \"-\", seq_end, \";\"\) from pdb_pfamA_reg r, pfamA a where a.pfamA_acc=r.pfamA_acc") or die "Can't prepare statement\n";
  $stpdb->execute() or die "Can't executre statement\n";
  my $arrayref = $stpdb->fetchall_arrayref();
    open (PDBFILE, ">$thisRelDir/pdbmap") or die "Can't open file to write\n";
   foreach my$row (@$arrayref){
       print PDBFILE $row->[0] . "\t" . $row->[1] . "\t" . $row->[2] . "\t" . $row->[3] . "\t" . $row->[4] . "\t" . $row->[5] . "\t" . $row->[6] . "\n";
   }
   close PDBFILE;
}

unless ( -e "$thisRelDir/Pfam.version" ) {
  $logger->info("Making Pfam.version file");
  my $version = $pfamDB->getSchema->resultset('Version')->search()->first;
  open( V, ">$thisRelDir/Pfam.version" )
    or
    $logger->logdie("Could not open $thisRelDir/Pfam.version for writing:[$!]");
  print V "Pfam release       : " . $version->pfam_release . "\n";
  print V "Pfam-A families    : " . $version->number_families . "\n";
  print V "Date               : "
    . substr( $version->pfam_release_date, 0, 7 ) . "\n";
  print V "Based on UniProtKB : " . $version->trembl_version . "\n";
  close(V);
}

unless ( -e "$thisRelDir/Pfam-A.regions.tsv" ) {
  $logger->info("Making Pfam-A.regions.tsv");
  my $host = $pfamDB->{host};
  my $user = $pfamDB->{user};
  my $password = $pfamDB->{password};
  my $port = $pfamDB->{port};
  my $db = $pfamDB->{database};
  my $cmd = "mysql -h $host -u $user -p$password -P $port $db --quick -e \"select pfamseq_acc, pfamA_acc, seq_start, seq_end from pfamA_reg_full_significant where in_full=1\" > regions";
  system($cmd) and $logger->logdie("Couldn't execute $cmd"); 
  #split regions file
  system("split -d -l 1000000 regions regions_") and $logger->logdie("Could not split regions file");
  my $dir = getcwd;
  my %filenames;

  opendir(DIR, $dir) or $logger->logdie("Couldn't open $dir $!");
  my @files = readdir(DIR);
  closedir(DIR);
  
  foreach my $file (@files){
    if ( $file =~ /regions_(\d+)/ ){
        $filenames{$1}=1;
    }
  }

  #submit jobs to farm
  my $queue = $config->{farm}->{lsf}->{queue};
  foreach my $number (keys %filenames){
      my $fh         = IO::File->new();
       $fh->open( "| bsub -q $queue -R \"select[mem>2000] rusage[mem=2000]\" -M 2000 -Jregions") or $logger->logdie("Couldn't open file handle [$!]\n");
       $fh->print( "get_regions.pl -num $number\n"); 
       $fh->close;        
  }
  #have jobs finished?
    if (-e "$logDir/finishedregions"){
	$logger->info("Already checked regions farm jobs have finished\n");
    } else {
	    my $fin = 0;
    	while (!$fin){
	        open( FH, "bjobs -Jregions|" );
	        my $jobs;
	        while (<FH>){
		    if (/^\d+/){
		        $jobs++;
		    }
	        }
	        close FH;
	        if ($jobs){
		        $logger->info("Regions farm jobs still running - checking again in 10 minutes\n");
		        sleep(600);
	        } else {
		        $fin = 1;
		        open( FH, "> $logDir/finishedregions" ) or $logger->logdie("Can not write to file");
		        close(FH);
	        }
	    }
    }

    #once jobs have finished - create the Pfam-A.regions.tsv file by concatenating the outputs and adding a header
    open (REGIONS, ">$thisRelDir/Pfam-A.regions.tsv") or $logger->logdie("Can't open file to write");
    print REGIONS "pfamseq_acc\tseq_version\tcrc64\tmd5\tpfamA_acc\tseq_start\tseq_end\n";
    close (REGIONS);

    system("cat regionsout_* >> $thisRelDir/Pfam-A.regions.tsv") and $logger->logdie("Failed to concatenate regions files");

}

unless(-e "$thisRelDir/Pfam-A.regions.uniprot.tsv" ) {
  $logger->info("Making Pfam-A.unkprot.tsv");
  my $host = $pfamDB->{host};
  my $user = $pfamDB->{user};
  my $password = $pfamDB->{password};
  my $port = $pfamDB->{port};
  my $db = $pfamDB->{database};
  my $cmd = "mysql -h $host -u $user -p$password -P $port $db --quick -e \"select uniprot_acc, pfamA_acc, seq_start, seq_end from uniprot_reg_full where in_full=1\" > uniprot_regions";
  system($cmd) and $logger->logdie("Couldn't execute $cmd"); 
  #split regions file
  system("split -d -l 1000000 uniprot_regions uniprot_regions_") and $logger->logdie("Could not split uniprot regions file");
  my $dir = getcwd;
  my %filenames;

  opendir(DIR, $dir) or $logger->logdie("Couldn't open $dir $!");
  my @files = readdir(DIR);
  closedir(DIR);
  
  foreach my $file (@files){
    if ( $file =~ /uniprot_regions_(\d+)/ ){
        $filenames{$1}=1;
    }    
  }

  #submit jobs to farm
  my $queue = $config->{farm}->{lsf}->{queue};
  foreach my $number (keys %filenames){
      my $fh         = IO::File->new();
       $fh->open( "| bsub -q $queue -R \"select[mem>2000] rusage[mem=2000]\" -M 2000 -Juniprotregions") or $logger->logdie("Couldn't open file handle [$!]\n");
       $fh->print( "get_regions.pl -uniprot -num $number\n"); 
       $fh->close;     
  }
  #have jobs finished?
    if (-e "$logDir/finisheduniprotregions"){
      $logger->info("Already checked uniprot regions farm jobs have finished\n");
    } else {
      my $fin = 0; 
      while (!$fin){
          open( FH, "bjobs -Juniprotregions|" );
          my $jobs;
          while (<FH>){
            if (/^\d+/){
              $jobs++;
            }    
          }    
          close FH;
          if ($jobs){
            $logger->info("Uniprot regions farm jobs still running - checking again in 10 minutes\n");
            sleep(600);
          } else {
            $fin = 1; 
            open( FH, "> $logDir/finisheduniprotregions" ) or $logger->logdie("Can not write to file");
            close(FH);
          }    
      }    
    }    

    #once jobs have finished - create the Pfam-A.regions.tsv file by concatenating the outputs and adding a header
    open (REGIONS, ">$thisRelDir/Pfam-A.regions.uniprot.tsv") or $logger->logdie("Can't open file to write");
    print REGIONS "uniprot_acc\tseq_version\tcrc64\tmd5\tpfamA_acc\tseq_start\tseq_end\n";
    close (REGIONS);

    system("cat uniprot_regionsout_* >> $thisRelDir/Pfam-A.regions.uniprot.tsv") and $logger->logdie("Failed to concatenate uniprot regions files");
}

unless ( -e "$thisRelDir/Pfam-A.clans.tsv" ) {
  $logger->info("Making Pfam-A.clans.tsv");

  my $stcl = $dbh->prepare("select a.pfamA_acc, m.clan_acc, clan_id, pfamA_id, description from pfamA a left join clan_membership m on a.pfamA_acc=m.pfamA_acc left join clan c on m.clan_acc=c.clan_acc ") or die "Can't prepare statement\n";
    $stcl->execute() or die "Can't executre statement\n";
  my $arrayref = $stcl->fetchall_arrayref();
    open (CLFILE, ">$thisRelDir/Pfam-A.clans.tsv") or die "Can't open file to write\n";
   foreach my$row (@$arrayref){
       print CLFILE $row->[0] . "\t" . $row->[1] . "\t" . $row->[2] . "\t" . $row->[3] . "\t" . $row->[4] . "\n";
   }
   close CLFILE;

}

unless ( -s "$thisRelDir/swisspfam" ) {
  $logger->info("Going to make swisspfam\n");
  makeSwissPfam( $thisRelDir, $updateDir );
}


# TODO Swisspfam style file fpr meta and ncbi

#unless( -e "$logDir/madeSeqInfo"){
#  $logger->info("Making seq info, they will take about 48 hours!!!");
#  #TODO $dbh->do("drop table if exists seq_info") or $logger->logdie("Error dropping seq_info table:".$dbh->errstr);
#  $dbh->do("CREATE TABLE seq_info AS
#  SELECT DISTINCT( p.pfamA_acc ),
#         p.pfamA_id,
#         p.description,
#         prf.auto_pfamA,
#         prf.auto_pfamseq,
#         ps.pfamseq_id,
#         ps.pfamseq_acc,
#         ps.description AS seq_description,
#         ps.species
#  FROM   pfamA AS p,
#         pfamseq AS ps,
#         pfamA_reg_full_significant AS prf
#  WHERE  prf.in_full = 1
#  AND    p.auto_pfamA     = prf.auto_pfamA
#  AND    prf.auto_pfamseq = ps.auto_pfamseq;") or $logger->logdie("Error generating seq_info table:".$dbh->errstr);
#  open(L, ">$logDir/madeSeqInfo") or $logger->logdie("Error opening $logDir/madeSeqInfo for writing:[$!]\n");
#  print L "Done\n";
#  close(L);
#}

#Dump the database.
# TODO - refactor make_ftp
unless ( -d "$thisRelDir/ftp" ) {
    $logger->info("Making ftp files");  
    make_ftp( $thisRelDir, $logger );
}


#make keyword indices

unless ( -d "$thisRelDir/SeqInfo" ){
    $logger->info("Making SeqInfo");
    my $seqinfo_dir = $thisRelDir . "/SeqInfo";
    mkdir($seqinfo_dir);
    system("makeSeqInfo.pl -all -dir $seqinfo_dir") and $logger->logdie("Could not run makeSeqInfo.pl");
    #check farm jobs are complete
        if (-e "$seqinfo_dir/finished_seqinfo"){
	    $logger->info("Already checked pfamA_ncbi jobs have finished\n");
    } else {
	    my $fin = 0;
	    while (!$fin){
	        open( FH, "bjobs -Jseqinfo|" );
	        my $jobs;
	        while (<FH>){
		        if (/^\d+/){
		            $jobs++;
		        }
	        }
	        close FH;
	        if ($jobs){
		        $logger->info("seqinfo jobs still running - checking again in 10 minutes\n");
		        sleep(600);
	        } else {
		        $fin = 1;
		        open( FH, "> $seqinfo_dir/finished_seqinfo" ) or die "Can not write to file finished_seqinfo";
		        close(FH);
	        }
	    }
    }

}

unless (-d "$thisRelDir/KW_indices"){
    $logger->info("Making keyword indices");
    my $index_dir = $thisRelDir . "/KW_indices";
    my $seqinfo_dir = $thisRelDir . "/SeqInfo";
    mkdir($index_dir);
    system("makeIndexes.pl -seq_files $seqinfo_dir -output $index_dir") and $logger->logdie("Could not run makeIndexes.pl");
}


###################################################################################################################

sub checkPfamseqSize {
  my ( $pfamseqdir, $pfamDB ) = @_;
  my ( $residues, $sequences );

  $logger->info("Running seqstat on pfamseq");

  # Use seqstat to make stats!
  open( TMP, "esl-seqstat $pfamseqdir/pfamseq |" )
    or $logger->logdie("Failed to run seqstat on $pfamseqdir/pfamseq:[$!]");
  while (<TMP>) {
    if (/^Total \# residues:\s+(\d+)/)   { $residues  = $1; }
    if (/^Number of sequences:\s+(\d+)/) { $sequences = $1; }
  }

  my $sequencesRDB = $pfamDB->getSchema->resultset('Pfamseq')->search( {} );

  unless ( $sequencesRDB == $sequences ) {
    $logger->logdie(
"Number of sequences in the database [$sequencesRDB] and in the pfamseq [$sequences] file do not tally"
    );
  }
  $logger->info("Number of sequences on disk and in the RDB are the same!");

  my $residuesRDB = $pfamDB->getSchema->resultset('Pfamseq')->search(
    {},
    {
      select => [ { sum => 'length' } ],
      as     => ['number_residues']
    }
  );

  unless ( $residues == $residuesRDB->first->get_column('number_residues') ) {
    $logger->logdie( "Number of residues in the database ["
        . $residuesRDB->first->get_column('number_residues')
        . "] and in the pfamseq [$residues] file do not tally" );
  }
  $logger->info("Number of residues on disk and in the RDB are the same!");
  return ( $sequences, $residues );
}

sub makeStats {
  my ( $releasedir, $num_seqs, $num_res ) = @_;
  $logger->info("Making stats.\n");
  system("flatfile_stats.pl $releasedir/Pfam-A.full $num_seqs $num_res > $releasedir/stats.txt");
  if ( -s "$releasedir/stats.txt" ) {
    $logger->info("Made stats");
  }
  else {
    $logger->logdie(
      "Run flatfile_stats.pl, but stats.txt does not exist or has no file size"
    );
  }
}

sub makePfamAScanFile {
  my ( $releasedir, $pfamDB ) = @_;

  open( PFAMSCAN, ">$releasedir/Pfam-A.hmm.dat" )
    or $logger->logdie("Could not open $releasedir/Pfam-A.scan.dat:[$!]");

  my @AllFamData =
    $pfamDB->getSchema->resultset("PfamA")
    ->search( undef, { order_by => \'me.pfama_id ASC' } );

  my %acc2id;
  foreach my $fam (@AllFamData) {
    $acc2id{ $fam->pfama_acc } = $fam->pfama_id;
  }

  foreach my $fam (@AllFamData) {
    print PFAMSCAN "# STOCKHOLM 1.0\n";
    print PFAMSCAN "#=GF ID   " . $fam->pfama_id . "\n";
    print PFAMSCAN "#=GF AC   " . $fam->pfama_acc . "." . $fam->version . "\n";
    print PFAMSCAN "#=GF DE   " . $fam->description . "\n";
    print PFAMSCAN "#=GF GA   "
      . $fam->sequence_ga . "; "
      . $fam->domain_ga . ";\n";
    print PFAMSCAN "#=GF TP   " . $fam->type . "\n";
    print PFAMSCAN "#=GF ML   " . $fam->model_length . "\n";

    my @nested =
      $pfamDB->getSchema->resultset("NestedLocation")
      ->search( { "pfama_acc" => $fam->pfama_acc } );

    foreach my $n (@nested) {
      my $nested_id = $acc2id{ $n->nested_pfama_acc->pfama_acc };
      print PFAMSCAN "#=GF NE   $nested_id\n";
    }

    my $clan = $pfamDB->getSchema->resultset("ClanMembership")->find(
      { pfama_acc => $fam->pfama_acc },
    );
    
    if ($clan) {
      print PFAMSCAN "#=GF CL   " . $clan->clan_acc->clan_acc . "\n";
    }
    print PFAMSCAN "//\n";
  }
  close(PFAMSCAN);
}

sub makeActiveSiteDat {
  my ( $releaseDir, $pfamDB ) = @_;

  my @allData=$pfamDB->getSchema->resultset('ActiveSiteHmmPosition')->search({}, { join => [qw(pfama_acc)]});
  
  my $file = $releaseDir . "/active_site.dat";
  open( FH, ">$file" ) or die "Couldn't open $file $!";


  my %asData;
  foreach my $row (@allData) {
    $asData{$row->pfama_acc->pfama_id}{$row->pfamseq_acc}.=" " if(exists($asData{$row->pfama_acc->pfama_id}{$row->pfamseq_acc}));
    $asData{$row->pfama_acc->pfama_id}{$row->pfamseq_acc}.= $row->residue.$row->hmm_position;
  }

  foreach my $pfamA_id (sort keys %asData) {
    print FH "ID  ".$pfamA_id."\n";

    foreach my $pfamseq_acc (sort { length($asData{$pfamA_id}{$b}) <=> length($asData{$pfamA_id}{$a}) } keys %{$asData{$pfamA_id}}) {  #Sort by length of pattern (this is important for removing subpatterns in pfam_scan.pl)
      print FH "$pfamseq_acc $asData{$pfamA_id}{$pfamseq_acc}\n";
    }
    print FH "//\n";
  }
  close FH;
}

sub checkReleaseNumbers {
  my ( $new_release, $old_release ) = @_;

  my ( $major, $point, $major_old, $point_old );

  if ( $new_release =~ /Rel(\d+)_(\d+)/ ) {
    $major = $1;
    $point = $2;
    $logger->info("Making PFAM release $major.$point");
  }
  else {
    $logger->logdie(
"Sorry your format for new release is incorrect should be Rel2_3 for example"
    );
  }

  if ( $old_release =~ /Rel(\d+)_(\d+)/ ) {
    $old_major = $1;
    $old_point = $2;
  }
  else {
    $logger->logdie(
"Sorry your format for old release is incorrect should be Rel2_2 for example"
    );
  }

  if ( $major != $old_major and $major != ( $old_major + 1 ) ) {
    $logger->logdie(
      "Sorry your release numbers don't tally [$major] [$old_major]");
  }
  if ( $point != ( $old_point + 1 ) and $point != 0 ) {
    $logger->logdie( "Sorry your release numbers don't tally", );
  }
  return ( $major, $point, $old_major, $old_point );
}

sub getTxtFiles {
  my $relDir = shift;
  my $ua     = LWP::UserAgent->new;
  $ua->agent("MyApp/0.1 ");

  foreach my $f (qw(userman.txt relnotes.txt)) {

    # Create a request
    unless ( -e "$relDir/$f" ) {
      $logger->debug("Fetching $f\n");
      my $req =
        HTTP::Request->new(
        GET => "ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/$f" );
      my $res = $ua->request($req);

      # Check the outcome of the response
      if ( $res->is_success ) {
        open( F, ">$relDir/$f" )
          or $logger->logdie("Can not open $relDir/$f:[$!]");
        print F $res->content;
        close;
      }
      else {
        $logger->logdie( "Failed to retrieve $f from ftp site:[ "
            . $res->status_line
            . "]\n" );
      }
    }
  }
}

sub getPfamseqFiles {
  my ( $relDir, $pfamseqDir, $config ) = @_;

  foreach my $f (qw(pfamseq uniprot uniprot uniprot_reference_proteomes.dat uniprot_sprot.dat uniprot_trembl.dat metaseq ncbi)) {
    unless ( -s "$relDir/$f.gz" ) {
      $logger->info("Copying $f");
      if ( -s "$pfamseqDir/$f.gz" ) {
        copy( "$pfamseqDir/$f.gz", "$relDir/$f.gz" )  || $logger->logdie( "Could not copy $f from $pfamseqDir to $relDir:[$!]");
        next;
      }
      elsif( -s "$pfamseqDir/$f" ) {
        copy( "$pfamseqDir/$f", "$relDir/$f" )  || $logger->logdie("Could not copy $f from $pfamseqDir to $relDir:[$!]");
      }
      elsif($f eq "metaseq") {
        copy($config->metaseqLoc."/$f", "$relDir/$f") || $logger->logdie("Could not copy $f from ".$config->metaseqLoc." to $relDir:[$!]");
      }
      elsif($f eq "ncbi") {
        copy($config->ncbiLoc."/$f", "$relDir/$f") || $logger->logdie("Could not copy $f from ".$config->ncbiLoc." to $relDir:[$!]");
      }
      else {
        $logger->logdie("Could not find $f in $pfamseqDir!");
      }
      
      my $pwd = getcwd;
      $logger->debug("Present working directory is:$pwd");
      chdir($relDir) or $logger->logdie("Could not cd to $relDir:[$!]");
      system("gzip $f") and $logger->logdie("Failed to gz $f:[$!]");
      chdir($pwd) or $logger->logdie("Could not cd to $pwd:[$!]");
    }
  }
}

sub errors {
  my ($errors) = @_;

  if ( $errors and scalar(@$errors) ) {
    open( ERRS, ">$thisRelDir/fatalErrors" )
      or $logger->logdie("Could not open $thisRelDir/fatalErrors");
    foreach my $e (@$errors) {
      print ERRS $e->{family} . "\t" . $e->{file} . "\t" . $e->{message} . "\n";
    }
    close(ERRS);
    $logger->logdie(
      "SERIOUS ERROR whilst making the flatfile!!! See thisRelDir/fatalErrors");
  }
}

sub makePfamAFlat {
  my ( $thisRelDir, $pfamDB ) = @_;

  #Get a list of all families
  my @families =
    $pfamDB->getSchema->resultset('PfamA')
    ->search( {}, { order_by => 'pfama_id ASC' } );
  $logger->info(
    "There will be " . scalar(@families) . " families in this release" );

  makePfamAFlatSeed( $thisRelDir, $pfamDB, \@families ) unless(-e "$thisRelDir/Pfam-A.seed") ;
  makePfamAFlatFull( $thisRelDir, $pfamDB, \@families ) unless(-e "$thisRelDir/Pfam-A.full") ;
  makePfamAFasta( $thisRelDir, $pfamDB, \@families ) unless(-e "$thisRelDir/Pfam-A.fasta");
  makePfamAHMMs( $thisRelDir, $pfamDB, \@families ) unless(-e "$thisRelDir/Pfam-A.hmm");
  foreach my $level (qw(rp15 rp35 rp55 rp75)) {
    makePfamAFlatRP( $thisRelDir, $pfamDB, \@families, $level ) unless(-e "$thisRelDir/Pfam-A.$level");
  }
  makePfamAUniprot( $thisRelDir, $pfamDB, \@families ) unless(-e "$thisRelDir/Pfam-A.full.uniprot");
  makePfamANcbi( $thisRelDir, $pfamDB, \@families ) unless(-e "$thisRelDir/Pfam-A.full.ncbi");
  makePfamAMeta( $thisRelDir, $pfamDB, \@families ) unless(-e "$thisRelDir/Pfam-A.full.metagenomics");
}

sub makePfamAFlatSeed {
  my ( $thiRelDir, $pfamDB, $families ) = @_;

  #Open up the seed alignment
  open( my $PFAMASEED, ">$thisRelDir/Pfam-A.seed" )
    || $logger->logdie("Could not open Pfam-A.seed");

  #Make all of the directories for putting the trees into
  my $treedir = "$thisRelDir/trees";
  unless ( -d $treedir ) {
    $logger->info("Making tree directory");
    mkdir($treedir)
      || $logger->logdie("Could not make directory  $treedir");
  }

  $logger->info("Checking SEEDs");
  my (@errors);
  foreach my $family (@$families) {

#How many regions do we expect according to pfamA_reg_seed, pfamA and the number so sequences in the
#file.
    my $seedCount =
      $pfamDB->getSchema->resultset('PfamARegSeed')
      ->search( { pfama_acc => $family->pfama_acc } );
    $logger->info( "Getting seed files for " . $family->pfama_id );

#------------------------------------------------------------------------------------
    ## THE SEED ALIGNMENT ##
    my $row = $pfamDB->getSchema->resultset('AlignmentAndTree')->find(
      {
        pfama_acc => $family->pfama_acc,
        type       => 'seed'
      }
    );

    if ( $row and $row->pfama_acc ) {

      #$acc, $type, $row, $outfile, $exptCount, $dbCount
      my $stoErrors =
        checkStockholmFile( $family->pfama_acc, 'seed', $row, $PFAMASEED,
        $family->num_seed, $seedCount->count );

      #If we get any errors add it on to the list of issues.
      if ( $stoErrors and scalar(@$stoErrors) ) {
        push( @errors, @$stoErrors );
      }
    }
    else {
      $logger->warn(
        "Could not find the seed row in the alignments and trees table for "
          . $family->pfama_id );
      push(
        @errors,
        {
          family => $family->pfama_acc,
          file   => 'seed',
          message =>
            'Could not find the seed row in the alignments and trees table'
        }
      );
    }

    #Check the JTMLs have size
    unless ( length( Compress::Zlib::memGunzip( $row->jtml ) ) > 10 ) {
      $logger->warn( 'The html [' . $family->pfama_acc . '] file has no size' );
      push(
        @errors,
        {
          family => $family->pfama_acc,
          file   => 'seedHTML',
          message =>
'The number of sequences in the flat file and the number in the seed regions do not match'
        }
      );
    }

    #Check the tree file and write to disk
    my $sTree = Compress::Zlib::memGunzip( $row->tree );
    unless ( length($sTree) > 10 ) {
      $logger->warn('The tree file has no size');
      push(
        @errors,
        {
          family  => $family->pfama_acc,
          file    => 'seedTree',
          message => 'The tree file ['
            . $family->pfama_acc
            . '] has insufficient size'
        }
      );
    }

    #Write the SEED alignment and tree files to disk!
    open( SEEDTREE, ">$treedir/" . $family->pfama_acc . ".tree" )
      || $logger->logdie("Error opening file");
    print SEEDTREE $sTree;
    close(SEEDTREE);
  }
  close($PFAMASEED);
  errors(\@errors);

#-------------------------------------------------------------------------------
}

sub checkStockholmFile {
  my ( $acc, $type, $row, $outfile, $exptCount, $dbCount ) = @_;

  my @errors;

  #Put the seed alignment into a local file so that we can QC it.
  my $fileContent = Compress::Zlib::memGunzip( $row->alignment );
  unless ( length($fileContent) > 10 ) {
    $logger->warn('The seed alignment has inappropriate size');
    push(
      @errors,
      {
        family  => $acc,
        file    => $type,
        message => 'Inappropriate size'
      }
    );
  }

  my ( $fileCount, $fileSQCount );
  open( TMP, "+>/tmp/$$.ali" )
    or $logger->logdie("Could not open /tmp/$$.ali:[$!]");

  #Print out the stockholm file
  print TMP $fileContent;
  seek( TMP, 0, 0 );
  while (<TMP>) {
    unless ($fileSQCount) {
      if (/^#=GF\s+SQ\s+(\d+)/) {
        $fileSQCount = $1;
      }
    }
    next if(/^$/);
    #This should be the raw lines in the file
    unless (/^(#|\/\/)/) {
      $fileCount++;
    }
  }
  close(TMP);

  #Now cross reference all of these numbers!
  if ( $fileCount != $exptCount ) {
    $logger->warn( "The number of sequences in the flat file [$acc] and "
        . "the number of $type regions do not match" );
    push(
      @errors,
      {
        family  => $acc,
        file    => $type,
        message => "The number of sequences in the flat file ["
          . $acc
          . "] and "
          . " the number of $type regions do not match"
      }
    );
  }

  if ( $fileSQCount != $exptCount ) {
    $logger->warn( "The number of sequences in #=GF line [$acc]"
        . " and the number of $type regions do not match" );
    push(
      @errors,
      {
        family => $acc,
        file   => 'seed',
        message =>
'The number of sequences in the flat file and the number in the seed regions do not match'
      }
    );

  }

  if ($dbCount) {
    if ( $dbCount != $exptCount ) {
      $logger->warn( "The number of sequences in db region table for [$acc]"
          . " and the number of $type regions do not match" );
      push(
        @errors,
        {
          family  => $acc,
          file    => 'seed',
          message => "The number of sequences in db region table for [$acc]"
            . " and the number of $type regions do not match"
        }
      );
    }
  }
  print $outfile $fileContent;
  return ( \@errors );
}

sub makePfamAFlatFull {
  my ( $thiRelDir, $pfamDB, $families ) = @_;

  #Open up the seed alignment
  open( my $PFAMAFULL, ">$thisRelDir/Pfam-A.full" )
    || $logger->logdie("Could not open Pfam-A.full");

  $logger->info("Checking FULLs");
  my (@errors);
  foreach my $family (@$families) {

    #If it has no members, don't add to file
    if($family->num_full == 0 ) {
      $logger->info($family->pfama_id." has no members in full");
      next;
    }

    #Get the number of expected regions from pfamA_reg_full
    my $fullCount =
      $pfamDB->getSchema->resultset('PfamARegFullSignificant')->search(
      {
        pfama_acc => $family->pfama_acc,
        in_full    => 1
      }
      );
    $logger->info( "Getting full files for " . $family->pfama_id );

#------------------------------------------------------------------------------------
    ## THE FULL ALIGNMENT ##
    my $row = $pfamDB->getSchema->resultset('AlignmentAndTree')->find(
      {
        pfama_acc => $family->pfama_acc,
        type       => 'full'
      }
    );

    if ( $row and $row->pfama_acc ) {

      #$acc, $type, $row, $outfile, $exptCount, $dbCount
      my $stoErrors =
        checkStockholmFile( $family->pfama_acc, 'full', $row, $PFAMAFULL,
        $family->num_full, $fullCount->count );
    }
    else {
      $logger->warn(
        "Could not find the full row in the alignments and trees table for "
          . $family->pfama_id );
      push(
        @errors,
        {
          family => $family->pfama_acc,
          file   => 'full',
          message =>
            'Could not find the full row in the alignments and trees table'
        }
      );
    }

    if ( $family->num_full <= 5000 ) {

      unless ( length( Compress::Zlib::memGunzip( $row->jtml ) ) > 10 ) {
        $logger->warn('The html file has no size');
        push(
          @errors,
          {
            family  => $family->pfama_acc,
            file    => 'fullHTML',
            message => 'Inappropriate size'
          }
        );
      }
    }
  }
  close($PFAMAFULL);
  errors(\@errors);
}

#-------------------------------------------------------------------------------
## THE FASTA FILE ##

sub makePfamAFasta {
  my ( $thisRelDir, $pfamDB, $families ) = @_;

  my @errors;

  #Opent the output file
  open( PFAMAFA, ">$thisRelDir/Pfam-A.fasta" )
    || $logger->logdie("Could not open Pfam-A.fasta");

  #For each family
  foreach my $family (@$families) {
    next if($family->num_full ==0);

    #Get the fasta file
    my $row =
      $pfamDB->getSchema->resultset('PfamAFasta')
      ->find( { pfama_acc => $family->pfama_acc } );

    #Check we have a row.
    if ( $row and $row->pfama_acc ) {
      $logger->info("Checking FASTA file");
      my $fa = Compress::Zlib::memGunzip( $row->fasta );

      if ( length($fa) > 10 ) {
        print PFAMAFA $fa;
      }
      else {
        $logger->warn("Fasta file has incorrect size!");
        push(
          @errors,
          {
            family  => $family->pfama_acc,
            file    => 'fasta',
            message => 'Incorrect size of fasta file'
          }
        );
      }

    }
    else {
      $logger->logdie(
        "Could not find the row in the fasta table for " . $family->pfama_id );
    }

  }
  errors(\@errors);
}

#-------------------------------------------------------------------------------
## THE HMMS ##

sub makePfamAHMMs {
  my ( $thisRelDir, $pfamDB, $families ) = @_;

  my @errors;

  #Open the PfamA HMM file.
  open( PFAMHMM, ">$thisRelDir/Pfam-A.hmm" )
    || $logger->logdie("Could not open Pfam.hmm");

  #Say what we are doing.
  $logger->info("Checking HMM files");

  #For every family
  foreach my $family (@$families) {

    #Grab the hmm row
    my $row =
      $pfamDB->getSchema->resultset('PfamAHmm')
      ->find( { pfama_acc => $family->pfama_acc } );

    #Check that we have found a row
    unless ( $row and $row->pfama_acc ) {
      $logger->logdie( "Could not find the row in the pfamA_HMM_ls table for "
          . $family->pfama_id );
    }

    #Check that the hmm row has size.
    if ( length( $row->hmm ) ) {

      #Print it
      print PFAMHMM $row->hmm;
    }
    else {
      #else warn!
      $logger->warn("hmm has no size");
      push(
        @errors,
        {
          family  => $family->pfama_acc,
          file    => 'hmm',
          message => 'No size'
        }
      );
    }
  }
  errors(\@errors);
}

#-------------------------------------------------------------------------------

sub makePfamAFlatRP {
  my ( $thisRelDir, $pfamDB, $families, $level ) = @_;

  #Open up the seed alignment
  open( my $PFAMARP, ">$thisRelDir/Pfam-A.$level" )
    || $logger->logdie("Could not open Pfam-A.$level");

  $logger->info("Checking $level");
  my $col = 'number_' . $level;
  my (@errors);
  foreach my $family (@$families) {
    next if ( !defined( $family->$col ) or $family->$col == 0 );

#------------------------------------------------------------------------------------
    ## THE FULL ALIGNMENT ##
    my $row = $pfamDB->getSchema->resultset('AlignmentAndTree')->find(
      {
        pfama_acc => $family->pfama_acc,
        type       => $level
      }
    );

    if ( $row and $row->pfama_acc ) {

      #$acc, $type, $row, $outfile, $exptCount, $dbCount
      my $stoErrors =
        checkStockholmFile( $family->pfama_acc, $level, $row, $PFAMARP,
        $family->$col );
    }
    else {
      $logger->warn(
        "Could not find the $level row in the alignments and trees table for "
          . $family->pfama_id );
      push(
        @errors,
        {
          family => $family->pfama_acc,
          file   => $level,
          message =>
            'Could not find the $level row in the alignments and trees table'
        }
      );
    }
  }
  close($PFAMARP);
  errors(\@errors);

}

sub makePfamAMeta {
  my ( $thisRelDir, $pfamDB, $families ) = @_;

  my @errors;
  open( PFAMAMETA, ">$thisRelDir/Pfam-A.full.metagenomics" )
    || $logger->logdie("Could not open Pfam-A.full.metagenomics");

  $logger->info("Checking Metagenomics files");
  foreach my $family (@$families) {
    next
      if ( !defined( $family->number_meta ) or $family->number_meta == 0 );

    my $row = $pfamDB->getSchema->resultset('AlignmentAndTree')->find(
      {
        pfama_acc => $family->pfama_acc,
        type       => 'meta'
      }
    );

    if ( $row and $row->pfama_acc ) {

      #Okay, looks like we have an alignment
      my $ali = Compress::Zlib::memGunzip( $row->alignment );
      if ( length($ali) > 10 ) {
        print PFAMAMETA $ali;
      }
      else {
        $logger->warn("Metagenomics ali has incorrect size");
        push(
          @errors,
          {
            family  => $family->pfama_acc,
            file    => 'metaAli',
            message => 'No size'
          }
        );
      }

    }
    else {
      $logger->warn("Failed to get metagenomics row");
      push(
        @errors,
        {
          family  => $family->pfama_acc,
          file    => 'metaAli',
          message => 'No row from database'
        }
      );
    }
  }
  close(PFAMAMETA);
  errors( \@errors );
}

sub makePfamAUniprot {
  my ( $thisRelDir, $pfamDB, $families ) = @_;

  my @errors;
  open( PFAMAUNIPROT, ">$thisRelDir/Pfam-A.full.uniprot" )
    || $logger->logdie("Could not open Pfam-A.full.uniprot");

  $logger->info("Checking Uniprot files");
  foreach my $family (@$families) {

    my $row = $pfamDB->getSchema->resultset('AlignmentAndTree')->find(
      {    
        pfama_acc => $family->pfama_acc,
        type       => 'uniprot'
      }    
    );   

    if ( $row and $row->pfama_acc ) {

      #Okay, looks like we have an alignment
      my $ali = Compress::Zlib::memGunzip( $row->alignment );
      if ( length($ali) > 10 ) {
        print PFAMAUNIPROT $ali;
      }    
      else {
        $logger->warn("Uniprot ali has incorrect size");
        push(
          @errors,
          {    
            family  => $family->pfama_acc,
            file    => 'uniprotAli',
            message => 'No size'
          }    
        );   
      }    

    }    
    else {
      $logger->warn("Failed to get Uniprot row");
      push(
        @errors,
        {    
          family  => $family->pfama_acc,
          file    => 'uinprotAli',
          message => 'No row from database'
        }    
      );   
    }    
  }
  close(PFAMAUNIPROT);
  errors( \@errors );
}



sub makePfamANcbi {
my ( $thisRelDir, $pfamDB, $families ) = @_;

  my @errors;
  open( PFAMANCBI, ">$thisRelDir/Pfam-A.full.ncbi" )
    || $logger->logdie("Could not open Pfam-A.full.ncbi");

  $logger->info("Checking NCBI files");
  foreach my $family (@$families) {
    next
      if ( !defined( $family->number_ncbi ) or $family->number_ncbi == 0 );

    my $row = $pfamDB->getSchema->resultset('AlignmentAndTree')->find(
      {
        pfama_acc => $family->pfama_acc,
        type       => 'ncbi'
      }
    );

    if ( $row and $row->pfama_acc ) {

      #Okay, looks like we have an alignment
      my $ali = Compress::Zlib::memGunzip( $row->alignment );
      if ( length($ali) > 10 ) {
        print PFAMANCBI $ali;
      }
      else {
        $logger->warn("NCBI ali has incorrect size");
        push(
          @errors,
          {
            family  => $family->pfama_acc,
            file    => 'ncbiAli',
            message => 'No size'
          }
        );
      }

    }
    else {
      $logger->warn("Failed to get NCBI row");
      push(
        @errors,
        {
          family  => $family->pfama_acc,
          file    => 'ncbiAli',
          message => 'No row from database'
        }
      );
    }
  }
  close(PFAMANCBI);
  errors( \@errors );

}

##########################################################
# Checks flatfile format, exits at first sign of trouble #
##########################################################
sub checkflat {
  my $file = shift;
  $logger->info("Checking format of $file");

  my $error;
  open( F, "checkflat.pl -v $file |" )
    || $logger->logdie("Failed to run checkflat.pl:[$!]");
  while (<F>) {
    if (/\S+/) {
      $logger->warn("ERROR with $file: [$_]");
      $error = 1;
    }
  }
  close F;

  if ($error) {
    $logger->logdie("Error in $file");
  }
}
##################
# Make swisspfam #
##################
sub makeSwissPfam {
  my ( $releasedir, $pfamseqdir ) = @_;
  $logger->info("Making swisspfam\n");

  #The next two system calls need to be reworked!
  if ( !-s "$pfamseqdir/pfamseq.len" ) {
    $logger->info(
      "Going to needlessly waste time and run pfamseq_lengths.pl, $pfamseqdir"
    );
    system(
"gunzip -c $pfamseqdir/uniprot_sprot.dat.gz $pfamseqdir/uniprot_trembl.dat.gz | pfamseq_lengths.pl > $pfamseqdir/pfamseq.len"
    ) and $logger->logdie("Failed to run pfamseq_lengths.pl:[$!]");
  }

  $logger->info(
    "Going to needlessly waste some more time and run swisspfam_start_ends.pl"
  );
  system(
"swisspfam_start_ends.pl $pfamseqdir/pfamseq.len $releasedir/Pfam-A.full > $releasedir/sw-pf"
  ) and $logger->logdie("Failed to run swusspfam_start_ends.pl\n");


  if ( !-s "$releasedir/sw-pf" ) {
    $logger->logdie( "No $releasedir/sw-pf file made!\n", 'die' );
  }

  $logger->info("Going to make swisspfam");
  system("mkswissPfam $releasedir/sw-pf > $releasedir/swisspfam")
    and $logger->logdie("Failed to run mkswissPfam:[$!]");
}

sub make_ftp {
  my ( $releasedir, $logger ) = @_;
  $logger->info("Making ftp files.\n");

  mkdir( "$releasedir/ftp", 0775 );
  if ( !-d "$releasedir/ftp" ) {
    $logger->logdie("Could not make ftp directory!");
  }

  #if ( !-d "$releasedir/ftp/proteomes"){
  #    system("cp -pr $relDir/proteomes $releasedir/ftp/proteomes") and $logger->logdie("Failed to copy proteomes directory");
  #}

  if ( !-e "$releasedir/trees.tgz" ) {
    system("tar zcf $releasedir/trees.tgz $releasedir/trees")
      and $logger->logdie("Failed to tgz trees directory");
  }
  my @list = qw(
    active_site.dat
    diff
    metaseq
    ncbi
    pdbmap
    Pfam-A.dead
    Pfam-A.fasta
    Pfam-A.full
    Pfam-A.full.uniprot
    Pfam-A.full.metagenomics
    Pfam-A.full.ncbi
    Pfam-A.hmm.dat
    Pfam-A.hmm
    Pfam-A.seed
    Pfam-A.rp15
    Pfam-A.rp35
    Pfam-A.rp55
    Pfam-A.rp75
    Pfam-C
    pfamseq
    relnotes.txt
    swisspfam
    uniprot
    uniprot_reference_proteomes.dat
    uniprot_sprot.dat
    uniprot_trembl.dat
    userman.txt
    Pfam.version
    Pfam-A.regions.tsv
    Pfam-A.regions.uniprot.tsv
    Pfam-A.clans.tsv
    trees.tgz
  );

  my @gzlist;
  foreach my $file (@list) {
    $logger->info("Working on $file");
    unless ( -e "$releasedir/$file" or -e "$releasedir/$file.gz" ) {
      $logger->logdie("The file $file in not in the release directory");
    }

    next
      if ( -e "$releasedir/ftp/$file.gz"
      or -e "$releasedir/ftp/$file.tgz" );

    if ( -e "$releasedir/$file.gz" ) {

      #copy it
      system("cp $releasedir/$file.gz $releasedir/ftp/$file.gz");
      push( @gzlist, $file );
    }
    elsif ( $file =~ /.*txt/ or $file =~ /\.*\.tgz/ ) {

      #copy it
      system("cp $releasedir/$file $releasedir/ftp/$file");
    }
    else {
      #gzip it
      system("gzip -c $releasedir/$file > $releasedir/ftp/$file.gz");
      push( @gzlist, $file );
    }
  }

  # Test all gzipped files exist and unzip ok
  foreach my $file (@gzlist) {
    if ( !-s "$releasedir/ftp/$file.gz" ) {
      $logger->logdie("Failed to make file $releasedir/ftp/$file.gz");
    }
  }

  #TODO copy whole dir tree to the ftp site.
}


sub help {
  print <<EOF;
  
  usage: $0 -old <Rel_old> -new <Rel_new> -relDir <dirlocation> -upDir <pfamseqDir>
  
  Options:
  old   : Old release number, e.g. Rel25_0
  
  
EOF
  print STDERR "Overrated!!!!\n";
  exit;
}
