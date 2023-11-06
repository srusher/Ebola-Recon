import numpy as np

# Sample data, replace with your 'fastANI' output
fastani_output = [
    "genome1 genome2 99.87%",
    "genome1 genome3 97.23%",
    "genome2 genome3 95.16%",
    # Add more lines for additional comparisons
]

# Create a set of all unique genome names
genome_names = set()
for line in fastani_output:
    parts = line.split()
    genome1, genome2 = parts[0], parts[1]
    genome_names.add(genome1)
    genome_names.add(genome2)

# Create an NxN matrix filled with zeros
num_genomes = len(genome_names)
matrix = np.zeros((num_genomes, num_genomes))

# Populate the matrix with 'fastANI' results
for line in fastani_output:
    parts = line.split()
    genome1, genome2 = parts[0], parts[1]
    similarity = float(parts[2].strip('%'))
    index1 = list(genome_names).index(genome1)
    index2 = list(genome_names).index(genome2)
    matrix[index1][index2] = similarity / 100
    matrix[index2][index1] = similarity / 100

# Display the pairwise NxN matrix
print("Genome names:", list(genome_names))
print("Pairwise NxN matrix:")
print(matrix)
