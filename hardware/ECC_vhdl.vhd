----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/07/2025 03:33:34 PM
-- Design Name: 
-- Module Name: ECC_vhdl_module - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ECC_vhdl_module is
    generic (
        C      : integer := 10;        -- Bit width number of classes or the segments size that we are going to correct
        ECC_bit: integer := 5          -- Number of bits for correction each column
    );
    port (
        d           : in  std_logic_vector(C-1 downto 0);  -- Input data vector
        p           : in  std_logic_vector(ECC_bit-1 downto 0);  -- Input ECC bits
        double_error: out std_logic;                        -- Output flag for double error
        dcw         : out std_logic_vector(C-1 downto 0)    -- Corrected data vector
    );
end entity ECC_vhdl_module;

architecture Behavioral of ECC_vhdl_module is
    signal dp : std_logic_vector(4 downto 0);  -- Parity calculated from input data
    signal s  : std_logic_vector(4 downto 0);  -- Syndrome bits
    signal df : std_logic_vector(9 downto 0);  -- Flag bit for getting correct data
    signal xw : std_logic;                     -- Intermediate signal for double error flag
begin

    -- Data Parity calculation
    dp(0) <= d(0) xor d(1) xor d(3) xor d(4) xor d(6) xor d(8);
    dp(1) <= d(0) xor d(2) xor d(3) xor d(5) xor d(6) xor d(9);
    dp(2) <= d(1) xor d(2) xor d(3) xor d(7) xor d(8) xor d(9);
    dp(3) <= d(4) xor d(5) xor d(6) xor d(7) xor d(8) xor d(9);
    dp(4) <= d(0) xor d(1) xor d(2) xor d(3) xor d(4) xor d(5) xor d(6) xor d(7) xor d(8) xor d(9) xor p(0) xor p(1) xor p(2) xor p(3);

    -- Syndrome: xor with actual parity
    s(0) <= p(0) xor dp(0);
    s(1) <= p(1) xor dp(1);
    s(2) <= p(2) xor dp(2);
    s(3) <= p(3) xor dp(3);
    s(4) <= p(4) xor dp(4);

    -- Flag bit for getting correct data
    df(0) <= s(0) and s(1) and not s(2) and not s(3) and s(4);
    df(1) <= s(0) and not s(1) and s(2) and not s(3) and s(4);
    df(2) <= not s(0) and s(1) and s(2) and not s(3) and s(4);
    df(3) <= s(0) and s(1) and s(2) and not s(3) and s(4);
    df(4) <= s(0) and not s(1) and not s(2) and s(3) and s(4);
    df(5) <= not s(0) and s(1) and not s(2) and s(3) and s(4);
    df(6) <= s(0) and s(1) and not s(2) and s(3) and s(4);
    df(7) <= not s(0) and not s(1) and s(2) and s(3) and s(4);
    df(8) <= s(0) and not s(1) and s(2) and s(3) and s(4);
    df(9) <= not s(0) and s(1) and s(2) and s(3) and s(4);

    -- Corrected data bits
    dcw(0) <= df(0) xor d(0);
    dcw(1) <= df(1) xor d(1);
    dcw(2) <= df(2) xor d(2);
    dcw(3) <= df(3) xor d(3);
    dcw(4) <= df(4) xor d(4);
    dcw(5) <= df(5) xor d(5);
    dcw(6) <= df(6) xor d(6);
    dcw(7) <= df(7) xor d(7);
    dcw(8) <= df(8) xor d(8);
    dcw(9) <= df(9) xor d(9);

    -- Intermediate signal for double error flag
    xw <= s(0) or s(1) or s(2) or s(3);

    -- Flag for double error
    double_error <= not s(4) and xw;  -- If 1, that means double error exists

end architecture Behavioral;
