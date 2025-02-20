import os
import re
import pandas as pd
from collections import defaultdict
from sympy import symbols, simplify_logic, Or
from itertools import product

# Function to read a MIF file and process its content
def process_mif_file(file_path):
    with open(file_path, "r") as file:
        lines = file.readlines()

    # Grouping values by occurrences in the file
    value_groups = defaultdict(list)
    
    for index, line in enumerate(lines):
        value = line.strip()
        value_groups[value].append(index)

    # Convert to dictionary
    grouped_data = dict(value_groups)

    # Determine the highest index for binary conversion
    max_index = max(max(indexes) for indexes in grouped_data.values())
    binary_length = len(bin(max_index)[2:])  # Get binary length

    # Convert line indexes to binary
    for key in grouped_data:
        grouped_data[key] = [format(index, f'0{binary_length}b') for index in grouped_data[key]]

    return grouped_data, binary_length

# Function to generate VHDL ROM-based LUT code
def generate_vhdl_rom(file_name, grouped_data, binary_length):
    vhdl_code = f"""
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ROM_LUT_{file_name} is
    Port (
        address : in STD_LOGIC_VECTOR({binary_length-1} downto 0);
        data_out : out STD_LOGIC_VECTOR(4 downto 0) -- 5-bit value
    );
end ROM_LUT_{file_name};

architecture Behavioral of ROM_LUT_{file_name} is
begin
    process(address)
    begin
        case address is
    """
    
    for value, indexes in grouped_data.items():
        for index in indexes:
            vhdl_code += f'            when "{index}" => data_out <= "{value}";\n'

    vhdl_code += """
            when others => data_out <= "00000"; -- Default case
        end case;
    end process;
end Behavioral;
    """
    
    return vhdl_code

# Function to generate minimized SOP-based VHDL
def generate_vhdl_sop(file_name, grouped_data, binary_length):
    num_output_bits = len(next(iter(grouped_data.keys())))  # Determine value bit width
    variables = [symbols(f'A{i}') for i in range(binary_length)]  # Define input variables
    simplified_expressions = {}

    # Generate simplified SOP for each output bit
    for bit_pos in range(num_output_bits):
        boolean_expressions_bit = []
        
        for value, binary_indexes in grouped_data.items():
            bit_value = int(value[bit_pos])
            if bit_value == 1:
                for binary_index in binary_indexes:
                    terms = [(variables[i] if bit == '1' else ~variables[i]) for i, bit in enumerate(binary_index)]
                    boolean_expressions_bit.append(Or(*terms))

        # Simplify SOP expression
        if boolean_expressions_bit:
            combined_expression = Or(*boolean_expressions_bit)
            simplified_expressions[f"V{bit_pos}"] = simplify_logic(combined_expression, form='dnf')

    # Generate VHDL code for SOP logic
    vhdl_code = f"""
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SOP_LUT_{file_name} is
    Port (
        A : in STD_LOGIC_VECTOR({binary_length-1} downto 0);
        V : out STD_LOGIC_VECTOR({num_output_bits-1} downto 0)
    );
end SOP_LUT_{file_name};

architecture Behavioral of SOP_LUT_{file_name} is
begin
"""

    for bit, expression in simplified_expressions.items():
        vhdl_code += f"    {bit} <= {expression};\n"

    vhdl_code += "end Behavioral;\n"

    return vhdl_code


for mif_file in mif_files:
    file_path = os.path.join(mif_directory, mif_file)
    file_name = os.path.splitext(mif_file)[0]
    
    print(f"Processing {mif_file}...")
    
    grouped_data, binary_length = process_mif_file(file_path)
    
    # Generate ROM-based LUT VHDL
    rom_vhdl = generate_vhdl_rom(file_name, grouped_data, binary_length)
    with open(f"ROM_LUT_{file_name}.vhd", "w") as vhdl_file:
        vhdl_file.write(rom_vhdl)
    
    # Generate SOP-optimized VHDL
    sop_vhdl = generate_vhdl_sop(file_name, grouped_data, binary_length)
    with open(f"SOP_LUT_{file_name}.vhd", "w") as vhdl_file:
        vhdl_file.write(sop_vhdl)
    
    print(f"Generated VHDL files for {mif_file}.")

def generate_vhdl_sop_with_dont_cares2(file_name, grouped_data, binary_length):
    num_output_bits = len(next(iter(grouped_data.keys())))  # Number of bits in each value
    variables = [symbols(f'A{i}') for i in range(binary_length)]  # Define input variables
    simplified_expressions = {}

    # Generate all possible binary addresses
    all_possible_indexes = {"{:0{width}b}".format(i, width=binary_length) for i in range(2**binary_length)}

    # Extract used indexes from the grouped data
    used_indexes = {index for indexes in grouped_data.values() for index in indexes}

    # Identify don't care conditions (addresses that are never used)
    dont_care_indexes = all_possible_indexes - used_indexes

    # Generate simplified SOP for each output bit
    for bit_pos in range(num_output_bits):
        minterms = []
        dont_cares = []

        for value, binary_indexes in grouped_data.items():
            bit_value = int(value[bit_pos])
            if bit_value == 1:
                minterms.extend(binary_indexes)  # These are minterms (where output is 1)
        
        # Use don't care conditions to help simplify
        dont_cares.extend(dont_care_indexes) 

        # Convert minterms and don't cares into Boolean expressions
        boolean_expressions_bit = []
        for binary_index in minterms:
            terms = [(variables[i] if bit == '1' else ~variables[i]) for i, bit in enumerate(binary_index)]
            boolean_expressions_bit.append(Or(*terms))

        # Simplify SOP using don't cares
        if boolean_expressions_bit:
            combined_expression = Or(*boolean_expressions_bit)
            simplified_expressions[f"V{bit_pos}"] = simplify_logic(combined_expression, form='dnf')

    # Generate VHDL code for SOP logic
    vhdl_code = f"""
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SOP_LUT_{file_name} is
    Port (
        A : in STD_LOGIC_VECTOR({binary_length-1} downto 0);
        V : out STD_LOGIC_VECTOR({num_output_bits-1} downto 0)
    );
end SOP_LUT_{file_name};

architecture Behavioral of SOP_LUT_{file_name} is
begin
"""

    for bit, expression in simplified_expressions.items():
        vhdl_code += f"    {bit} <= {expression};\n"

    vhdl_code += "end Behavioral;\n"

    return vhdl_code
    
vhdl_file_path = os.path.join(output_dir, f"SOP_LUT_{file_name}.vhd")
with open(vhdl_file_path, "w") as vhdl_file:
    vhdl_file.write(vhdl_code)
