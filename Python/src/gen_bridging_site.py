import random
import re
import argparse

# Function to extract gates/nodes from a netlist file
def extract_nodes(netlist_file):
    nodes = set()
    with open(netlist_file, 'r') as f:
        for line in f:
            # Match gates and their identifiers, assuming format like: INVXL U58 ( .A(X_6), .Y(n60) );
            match = re.search(r'\b(\w+)\s+(U\d+)\s*\(', line)
            if match:
                # print(match)
                gate_name = match.group(2)  # Extract the gate identifier (e.g., U58)
                nodes.add(gate_name)
    return list(nodes)

# Function to randomly select pairs of nodes
def generate_random_pairs(nodes, num_pairs):
    if len(nodes) < 2:
        raise ValueError("Not enough nodes to form pairs.")
    return random.sample([(a, b) for a in nodes for b in nodes if a != b], num_pairs)

# Function to save pairs to a file
def save_pairs_to_file(pairs, output_file):
    with open(output_file, 'w') as f:
        for pair in pairs:
            f.write(f"{pair[0]} {pair[1]}\n")

# Main function
def generate_bridging_site(netlist_file, num_pairs=1000):
    output_file = "nodes.txt"

    print("Extracting nodes from netlist...")
    nodes = extract_nodes(netlist_file)

    if len(nodes) < 2:
        print("Error: Not enough nodes found in the netlist.")
        return

    print(f"Found {len(nodes)} nodes. Generating {num_pairs} random pairs...")
    pairs = generate_random_pairs(nodes, num_pairs)

    print(f"Saving pairs to {output_file}...")
    save_pairs_to_file(pairs, output_file)

    print(f"Random pairs saved to {output_file}.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate random pairs of nodes from a netlist file.')
    parser.add_argument('netlist_file', help='Path to the netlist file')
    parser.add_argument('--num_pairs', type=int, default=1000, help='Number of random pairs to generate (default: 1000)')
    args = parser.parse_args()
    generate_bridging_site(args.netlist_file, args.num_pairs)
