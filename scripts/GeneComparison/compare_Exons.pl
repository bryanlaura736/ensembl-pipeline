#!/usr/local/ensembl/bin/perl


=head1 NAME

comapre_Exons
 
=head1 DESCRIPTION

reads the config options from Bi::Ensembl::Pipeline::GeneComparison::GeneCompConf
and reads as input an input_id in the style of other Runnables, i.e. -input_id chr_name.chr_start-chr_end

=head1 OPTIONS

    -input_id  The input id: chrname.chrstart-chrend

=cut

use strict;  
use diagnostics;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::GeneComparison::GeneComparison;
use Getopt::Long;

## load all the parameters
use Bio::EnsEMBL::Pipeline::GeneComparison::GeneCompConf;

# annotation
my $host1   = $DBHOST1;
my $dbname1 = $DBNAME1;
my $path1   = $PATH1;
my $type1   = $GENETYPES1;
my $user1   = $DBUSER1;

# prediction
my $host2   = $DBHOST2;
my $dbname2 = $DBNAME2;
my $path2   = $PATH2;
my $type2   = $GENETYPES2;
my $user2   = $DBUSER2;

# reference db
my $ref_host   = $REF_DBHOST;
my $ref_dbname = $REF_DBNAME;
my $ref_path   = $REF_PATH;
my $ref_user   = $REF_DBUSER;


my $runnable;
my $input_id;
my $write  = 0;
my $check  = 0;
my $params;
my $pepfile;

my $gff_file;

# can override db options on command line
&GetOptions( 
	    'input_id:s'  => \$input_id,
	    'gff_file:s'  => \$gff_file,
	   );

unless( $input_id){     
  print STDERR "Usage: run_GeneComparison.pl -input_id < chrname.chrstart-chrend >\n";
  exit(0);
}
    
# get genomic region 
my $chr      = $input_id;
$chr         =~ s/\.(.*)-(.*)//;
my $chrstart = $1;
my $chrend   = $2;

unless ( $chr && $chrstart && $chrend ){
       print STDERR "bad input_id option, try something like 20.1-5000000\n";
}

# connect to the databases 
my $dna_db= new Bio::EnsEMBL::DBSQL::DBAdaptor(-host  => $ref_host,
					       -user  => $ref_user,
					       -dbname=> $ref_dbname);
$dna_db->static_golden_path_type($ref_path); 


my $db1= new Bio::EnsEMBL::DBSQL::DBAdaptor(-host  => $host1,
					    -user  => $user1,
					    -dbname=> $dbname1);
print STDERR "Connected to database $dbname1 : $host1 : $user1 \n";


my $db2= new Bio::EnsEMBL::DBSQL::DBAdaptor(-host  => $host2,
					    -user  => $user2,
					    -dbname=> $dbname2,
					    -dnadb => $dna_db);

print STDERR "Connected to database $dbname2 : $host2 : $user2 \n";



# use different golden paths
$db1->static_golden_path_type($path1); 
$db2->static_golden_path_type($path2); 

my $sgp1 = $db1->get_StaticGoldenPathAdaptor;
my $sgp2 = $db2->get_StaticGoldenPathAdaptor;
my $sgp3 = $dna_db->get_StaticGoldenPathAdaptor;

# get a virtual contig with a piece-of chromosome #
my ($vcontig1,$vcontig2);

print STDERR "Fetching region $chr, $chrstart - $chrend\n";
$vcontig1 = $sgp1->fetch_VirtualContig_by_chr_start_end("chr20",$chrstart,$chrend);
$vcontig2 = $sgp2->fetch_VirtualContig_by_chr_start_end($chr,$chrstart,$chrend);
my $vcontig3 = $sgp3->fetch_VirtualContig_by_chr_start_end($chr,$chrstart,$chrend);

# get the genes of type @type1 and @type2 from $vcontig1 and $vcontig2, respectively #
my (@genes1,@genes2);
my (@trascripts1,@transcripts2);

foreach my $type ( @{ $type1 } ){
  print STDERR "Fetching genes of type $type\n";
  my @more_genes = $vcontig1->get_Genes_by_Type($type);
  my @more_trans = ();
  foreach my $gene ( @more_genes ){
    push ( @more_trans, $gene->each_Transcript );
  }
  push ( @genes1, @more_genes ); 
  print STDERR scalar(@more_genes)." genes found\n";
  print STDERR "with ".scalar(@more_trans)." transcripts\n";
}

foreach my $type ( @{ $type2 } ){
  print STDERR "Fetching genes of type $type\n";
  my @more_genes = $vcontig2->get_Genes_by_Type($type);
  my @more_trans = ();
  foreach my $gene ( @more_genes ){
    push ( @more_trans, $gene->each_Transcript );
  }
  push ( @genes2, @more_genes ); 
  print STDERR scalar(@more_genes)." genes found\n";
  print STDERR "with ".scalar(@more_trans)." transcripts\n";
}

#my @extra_genes = $vcontig3->get_Genes_by_Type("ensembl");
#my @extra_trans = ();
#foreach my $gene ( @extra_genes ){
#  push ( @extra_trans, $gene->each_Transcript );
#}
#print STDERR scalar(@extra_genes)." genes of type ensembl found\n";
#print STDERR "with ".scalar(@extra_trans)." transcripts\n";
#push( @genes2, @extra_genes );


# get a GeneComparison object 
my $gene_comparison = 
  Bio::EnsEMBL::Pipeline::GeneComparison::GeneComparison->new(					     
							      '-annotation_db'    => $db1,
							      '-prediction_db'    => $db2,
							      '-annotation_genes' => \@genes1,
							      '-prediction_genes' => \@genes2,
							      '-input_id'         => $input_id,
							     );



#########################################################

## cluster the genes we have passed to $gene_comparison

my @gene_clusters    = $gene_comparison->cluster_Genes;
my @unclustered = $gene_comparison->unclustered_Genes;

## print out the results of the clustering:

my @unclustered1;
my @unclustered2;

UNCLUSTER:
foreach my $uncluster ( @unclustered ){
  my @gene = $uncluster->get_Genes;
  if ( scalar(@gene)>1 ){
    print STDERR "genes @gene are wrongly unclustered\n";
  }
  my $this_type = $gene[0]->type;
  foreach my $type ( @{ $type1 } ){
    if ( $this_type eq $type ){
      push( @unclustered1, $uncluster );
      next UNCLUSTER;
    }
  }
  foreach my $type ( @{ $type2 } ){
    if ( $this_type eq $type ){
      push( @unclustered2, $uncluster );
      next UNCLUSTER;
    }
  }
}

print STDERR scalar(@gene_clusters)." gene clusters formed\n";
print STDERR scalar(@unclustered1)." genes of type @$type1 left unclustered\n";
print STDERR scalar(@unclustered2)." genes of type @$type2 left unclustered\n";

if ( $gff_file ){  
  $gene_comparison->gff_file($gff_file);
}

# run the analysis
$gene_comparison->compare_Exons(\@gene_clusters,0,'verbose');


