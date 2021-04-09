rule all:
    input:
        auspice_json = "auspice/ecozur-roary.json",

# names of files used in the analysis
seq_file = "data/core_gene_alignment_beast.fasta"
#ref_file = "data/core.ref.fa"
meta_file = "data/ecozur_259_meta.tsv"
colors_file = "config/colors.tsv"
auspice_config_file = "config/auspice_config.json"
geo_info_file = "config/latlon.tsv"

rule tree:
    input:
        aln = seq_file,
    output:
        "results/tree_raw.nwk"
    params:
        method = 'iqtree' ,
        sub_mode = 'GTR' ,
    shell:
        """
        augur tree --alignment {input.aln} \
            --method {params.method} \
            --substitution-model {params.sub_mode} \
            --output {output}
        """

rule refine:
    input:
        tree = rules.tree.output,
        aln = seq_file,
        metadata = meta_file,
    output:
        tree = "results/tree.nwk",
        node_data = "results/branch_lengths.json",
    params:
        root = 'min_dev',
        coal = 'opt', 
        gen = '150',
        date_infer = 'marginal',
        clock_rate = '0.00000069',
        branch_infer = 'auto' ,
        clock_iqd = '4',
    shell:
        """
        augur refine --tree {input.tree} \
            --alignment {input.aln} \
            --metadata {input.metadata} \
            --timetree \
            --root {params.root} \
            --coalescent {params.coal} \
            --date-inference {params.date_infer} \
            --date-confidence \
            --branch-length-inference {params.branch_infer} \
            --clock-rate {params.clock_rate} \
            --clock-filter-iqd {params.clock_iqd} \
            --gen-per-year {params.gen} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data}
        """

rule traits:
    input:
        tree = rules.refine.output.tree,
        meta = meta_file
    output:
        "results/traits.json"
    params:
        traits = 'site_id gradient PCR genome'
    shell:
        """
        augur traits --tree {input.tree} \
            --metadata {input.meta} \
            --columns {params.traits} \
            --output-node-data {output}
        """

rule export:
    input:
        tree = rules.refine.output.tree,
        metadata = meta_file,
        branch_lengths = rules.refine.output.node_data,
        traits = rules.traits.output,
        color_defs = colors_file,
        auspice_config = auspice_config_file,
        geo_info = geo_info_file,
    output:
        auspice_json = rules.all.input.auspice_json,
    shell:
        """
        augur export v2 \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --node-data {input.branch_lengths} {input.traits} \
            --auspice-config {input.auspice_config} \
            --colors {input.color_defs} \
            --lat-longs {input.geo_info} \
            --output {output.auspice_json} \
        """

rule clean:
    message: "Removing directories: {params}"
    params:
        "results ",
        "auspice"
    shell:
        "rm -rfv {params}"