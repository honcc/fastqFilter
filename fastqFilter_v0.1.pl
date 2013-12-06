#!/usr/bin/perl/ -w
$|++; #---turn on the auto flush for the progress bar
use strict;
use Time::HiRes qw( time );

######################################################################################################################################################
#
#	Description
#		This is a perl script to filter fastq files (in both flat or gz format) based on a series of criteria, including length etc. The output is in gz format.
#
#	Input
#		--fastqGZPath=			file path; [compulsory]; path of the fastq file in gz format;
#		--uniLength=			integer; [0]; the target lengths of the read; read length longer than --uniLength= will be trimmed, short than --uniLength= will be discarded; use "0" to disable;
#		--maxLength=			integer; [999]; the maximum lengths of the read; read length longer than --maxLength= will be discarded; use "0" to disable;
#		--minLength=			integer; [25]; the minimum lengths of the read; read length shorter than --minLength= will be discarded; use "0" to disable;
#		--outDir=				dir path; [./fastqFilter/]; output directory;
#
#	Output
#
#	Usage
#		perl fastqFilter_v0.1.pl --fastqGZPath=/Volumes/A_MPro2TB/NGS/fastq/tmpTestPolyALen/1301_herbSeq_DMSO_T0H_2.clean.fastq.gz --uniLength=100
#
#	Assumption
#
#	Version history
#
#		v0.1
#			-debut;
#
#####################################################################################################################################################

#==========================================================Main body starts==========================================================================#
my ($fastqGZPath, $uniLength, $minLength, $maxLength, $outDir) = readParameters();

filterFastqOnTheFly($fastqGZPath, $uniLength, $minLength, $maxLength, $outDir);

printCMDLog();

########################################################################## readParameters
sub readParameters {
	
	my ($fastqGZPath, $uniLength, $minLength, $maxLength, $outDir);
	
	$uniLength = 0;
	$minLength = 25;
	$maxLength = 999;
	$outDir= "./fastqFilter";
	
	foreach my $param (@ARGV) {
		if ($param =~ m/--fastqGZPath=/) {$fastqGZPath = substr ($param, index ($param, "=")+1);}
		elsif ($param =~ m/--uniLength=/) {$uniLength = substr ($param, index ($param, "=")+1);}
		elsif ($param =~ m/--minLength=/) {$minLength = substr ($param, index ($param, "=")+1);}
		elsif ($param =~ m/--maxLength=/) {$maxLength = substr ($param, index ($param, "=")+1);}
		elsif ($param =~ m/--outDir=/) {$outDir = substr ($param, index ($param, "=")+1);}
	}
	
	system ("mkdir -p -m 777 $outDir");
	
	return ($fastqGZPath, $uniLength, $minLength, $maxLength, $outDir);
}
########################################################################## printEditedFileOnTheFly
sub filterFastqOnTheFly {
	
	my ($fastqGZPath, $uniLength, $minLength, $maxLength, $outDir) = @_;
	
	my @fastqGZPathSplt = split /\//, $fastqGZPath;
	$fastqGZPathSplt[-1] =~ s/\.\w+$//;
	open (INPIGZ, "gzip -d -c $fastqGZPath |");
	open (OUTPIGZ, "| pigz -c >$outDir/$fastqGZPathSplt[-1].filter.fastq.gz");
	my $readProc = my $readAccept = 0;
	my $progCount = 100000;
	my $header = 'HWI';
	
	while (chomp(my $theLine = <INPIGZ>)) {
		
		if ($theLine =~ m/^\@$header/) {#---sequence header, assume 4 lines consists a read
			
			$readProc++;
			if ($progCount == 100000) {
				my $pctAccept = sprintf "%.02f", 100*$readAccept/$readProc;
				open (STATUSLOG, ">$outDir/progress.log.txt");
				print STATUSLOG "$readProc\treadProc\n";
				print STATUSLOG "$readAccept\treadAccept\n";
				print STATUSLOG "$pctAccept\tpctAccept\n";
				close STATUSLOG;
				$progCount = 0;
			}
			$progCount++;
			
			my $accepted = 'yes';
			
			chomp (my $seqHeader = $theLine); $seqHeader =~ s/^\@//;
			chomp (my $seq = <INPIGZ>);
			chomp (my $qualHeader = <INPIGZ>); $qualHeader =~ s/^\+//;
			chomp (my $qual = <INPIGZ>);

			my $length = length $seq;

			#---check 4-lines-per-read format
			die "This fastq file doesnt seem to be in 4-lines-per-read format. Program terminated.\n" if ($qualHeader =~ m/^\+/);

			if (($length >= $minLength) and ($length <= $maxLength)) {
					
				if ($uniLength != 0) {
					if ($length >= $uniLength) {
						$seq = substr $seq, 0, $uniLength;
						$qual = substr $qual, 0, $uniLength;
					} else {
						$accepted = 'no';
					}
				} else {
					#---not checking uniLength
				}
			
			} else {
				$accepted = 'no';
			}
			
			if ($accepted eq 'yes') {
				$readAccept++;
				print OUTPIGZ "\@".$seqHeader."\n";
				print OUTPIGZ $seq."\n";
				print OUTPIGZ "\+\n";
				print OUTPIGZ $qual."\n";
			}
		}
		last if (eof INPIGZ);
	}

	close OUTPIGZ;
	close INPIGZ;

}
########################################################################## printCMDLogOrFinishMessage
sub printCMDLog {

	#---open a log file if it doesnt exists
	my $scriptNameXext = $0;
	$scriptNameXext =~ s/\.\w+$//;
	open (CMDLOG, ">>$scriptNameXext.cmd.log.txt"); #---append the CMD log file
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	my $runTime = sprintf "%04d-%02d-%02d %02d:%02d", $year+1900, $mon+1,$mday,$hour,$min;	
	print CMDLOG "[".$runTime."]\t"."perl $0 ".(join " ", @ARGV)."\n";
	close CMDLOG;
	
}
