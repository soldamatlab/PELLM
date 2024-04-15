using DESilico
using Distances
using CSV
using DataFrames
using FileIO

include("types.jl")
include("utils.jl")
include("distance_maximizer.jl")
include("library_select.jl")
include("cumulative_select.jl")
include("neighborhood_search.jl")

# ___ Data specific parameters ___
# GB1
data_path = joinpath(@__DIR__, "..", "..", "data", "GB1")
wt_string = "MQYKLILNGKTLKGETTTEAVDAATAEKVFKQYANDNGVDGEWTYDDATKTFTVTE"  # ['V', 'D', 'G', 'V']
mutation_positions = [39, 40, 41, 54]
missing_fitness_value = 0.0

# PhoQ
#= data_path = joinpath(@__DIR__, "..", "..", "data", "PhoQ")
wt_string = "MKKLLRLFFPLSLRVRFLLATAAVVLVLSLAYGMVALIGYSVSFDKTTFRLLRGESNLFYTLAKWENNKLHVELPENIDKQSPTMTLIYDENGQLLWAQRDVPWLMKMIQPDWLKSNGFHEIEADVNDTSLLLSGDHSIQQQLQEVREDDDDAEMTHSVAVNVYPATSRMPKLTIVVVDTIPVELKSSYMVWSWFIYVLSANLLLVIPLLWVAAWWSLRPIEALAKEVRELEEHNRELLNPATTRELTSLVRNLNRLLKSERERYDKYRTTLTDLTHSLKTPLAVLQSTLRSLRSEKMSVSDAEPVMLEQISRISQQIGYYLHRASMRGGTLLSRELHPVAPLLDNLTSALNKVYQRKGVNISLDISPEISFVGEQNDFVEVMGNVLDNACKYCLEFVEISARQTDEHLYIVVEDDGPGIPLSKREVIFDRGQRVDTLRPGQGVGLAVAREITEQYEGKIVAGESMLGGARMEVIFGRQHSAPKDE"
mutation_positions = [284, 285, 288, 289]
missing_fitness_value = 0.0 =#

wt_sequence = collect(wt_string)
seq_embedding_csv_file = "esm-1b_embedding_complete.csv"
sequence_embeddings = CSV.read(joinpath(data_path, seq_embedding_csv_file), DataFrame)
sequence_embeddings = Matrix{Float64}(sequence_embeddings)
sequence_embeddings = transpose(sequence_embeddings)

sequences = _get_sequences(data_path, "esm-1b_variants.csv", wt_string, mutation_positions)
variants_complete = _get_variants(data_path, "esm-1b_variants_complete.csv")
sequences_complete = _construct_sequences(variants_complete, wt_string, mutation_positions)

fitness_csv_file = "esm-1b_fitness_norm.csv"
fitness = CSV.read(joinpath(data_path, fitness_csv_file), DataFrame)
fitness = [values(row)[1] for row in eachrow(fitness)]

#neighborhoods = _construct_neighborhoods(sequence_embeddings)
neighborhoods = load(joinpath(@__DIR__, "data", "neighborhoods", "phoq_esm1b_euclidean.jld2"))["neighborhoods"]

# ___ Screening ___
screening = DESilico.DictScreening(Dict(sequences .=> fitness), missing_fitness_value)

results = Vector{Float64}(undef, length(variants_complete))
screened = Vector{Int}(undef, length(variants_complete))
save_period = 500
for (v, variant) in enumerate(variants_complete)
    # ___ Change starting sequence ___
    starting_sequence = _construct_sequence(variant)

    # ___ First de! ___
    wt_variant = Variant(starting_sequence, screening(starting_sequence))
    sequence_space = SequenceSpace([wt_variant])
    #= distance_maximizer = DistanceMaximizer(sequences_complete, sequence_embeddings)
    cumulative_select = CumulativeSelect(sequence_space.population)
    de!(
        sequence_space;
        screening,
        selection_strategy=cumulative_select,
        mutagenesis=distance_maximizer,
        n_iterations=9,
    ) =#

    # ___ Second de! ___
    knn = 16
    neighborhood_search = NeighborhoodSearch(
        sequences_complete,
        neighborhoods[1:knn, :];
        repeat=false,
        screened=map(variant -> variant.sequence, collect(sequence_space.variants)),
    )
    #= library_select = LibrarySelect(1, sequence_space.variants)
    parent_sequence = library_select()[1]
    sequence_space = SequenceSpace([Variant(parent_sequence, screening(parent_sequence))])
    DESilico.push_variants!(sequence_space, collect(library_select.library)) =#
    library_select = LibrarySelect(1, Vector{Variant}([]))
    de!(
        sequence_space;
        screening,
        selection_strategy=library_select,
        mutagenesis=neighborhood_search,
        n_iterations=nothing,
        screening_budget=384,
    )

    # ___ Save results ___
    results[v] = sequence_space.top_variant.fitness
    screened[v] = length(sequence_space.variants)

    # ___ Save data ___
    if v % save_period == 0
        println("$(v)/$(length(variants_complete))")
        save(
            joinpath(@__DIR__, "data", "PhoQ", "neighborhood_de", "results_$(v).jld2"),
            "results", results[v-save_period+1:v],
            "screened", screened[v-save_period+1:v],
        )
    end
end

save(
    joinpath(@__DIR__, "data", "PhoQ", "neighborhood_de", "results_complete.jld2"),
    "results", results,
    "screened", screened,
)
