#!/usr/bin/env perl
# $Source: /tmp/ENSCOPY-ENSEMBL-PIPELINE/scripts/examples/print_refseq_transcripts.pl,v $
# $Revision: 1.2 $

# # # 
# You'll need bioperl and the ensembl core checkout in your PERL5LIB
# This script can be modified to fetch genes from the core database
# # # 

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Getopt::Long;

# database
my $species; # = 'Homo sapiens';
my $host = 'ensembldb.ensembl.org';
my $user = 'anonymous';
my $port = 5306;

# genomic location
my $logic_name; # = 'refseq_human_import';

# # # usage
my $help = '';
$|=1;

if ( !GetOptions( 'logicname|l=s' => \$logic_name,
                  'species|s=s' => \$species,
                  'help|h!'     => \$help )
     || !( defined($logic_name) && defined($species) )
     || $help )
{
  print <<END_USAGE;

Usage:
  $0 --species=species --logicname=logic_name
  $0 --help

    --species / -s  Name of species. Alternate loci are currently only
                    available for human. 

    --logicname / -l    Logic_name for refseq import analysis 

    --help    / -h  To see this text.

Example usage:

  $0 -s human -n refseq_human_import

END_USAGE

  exit(1);
} ## end if ( !GetOptions( 'logicname|c=s'...))

# # # usage

# connect to database:
my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_registry_from_db( '-host' => $host, 
                                  '-port' => $port,
                                  '-user' => $user, );

# get adaptors
my $gene_adaptor = $registry->get_adaptor( $species, 'otherfeatures', 'Gene' );
my $slice_adaptor = $registry->get_adaptor( $species, 'otherfeatures', 'Slice' );
print "\nConnected to $species database\n\n";

# we need to go through the slices
my $slices = $slice_adaptor->fetch_all('toplevel',undef, 1); 

foreach my $slice (@$slices) {
  # fetch genes from refseq
  my $genes = $slice->get_all_Genes($logic_name);
  print STDERR "Fetched ".scalar(@$genes)." genes from slice ".$slice->name."\n";
  # Loop through genes and print gene and transcript IDs
  foreach my $gene (@$genes) {
    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      print $logic_name."\tGene_ID=".$gene->stable_id."\tGene_biotype=".$gene->biotype.
            "\tTranscript_name=".$transcript->stable_id."\tTranscript_biotype=".$transcript->biotype."\n"
    }
  }
}
