
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

use IEEE.STD_LOGIC_TEXTIO.ALL; -- Use this for text files with std_logic
use std.textio.all;            -- Standard text I/O package

-- for the memory parimiters the heighst is chosen and the rest are zero paddings!
ENTITY top_testCHVs IS
	GENERIC (C  : INTEGER := 10 ;			----bit width number of classes or the segments size that we are going to correct
            n : INTEGER := 10;		 --; 	-- bit--widths of main memory pointer, here used for the flagmemory
            index : INTEGER := 10;		 --; 	-- the index of the segment that this test module should work on
            Num_ECC_correctoin  : INTEGER := 10 ;	  ---- number of columns that are sensitive
            Num_parity  : INTEGER := 10 ;	  ---- number of columns that are not sensitive D - Num_ECC_correctoin
            lenPointerToECC  : INTEGER := 10 ;	  ---- log2(Num_ECC_correctoin)
            lenPointerToparity  : INTEGER := 10 ;	  ---- log2(Num_parity)
            ECC_bit		: INTEGER := 5  );	---- NUmber of bits for correction each column 
	PORT (
		clk, rst 				: IN STD_LOGIC;
		run		 				: IN STD_LOGIC;  ------ when each column is going to be compared
		done					: IN STD_LOGIC;  ------ the last column of CHV
		CHVin				    : IN STD_LOGIC_vector(C-1 Downto 0);
        FlagPointer		 	    : IN STD_LOGIC_VECTOR(n-1 DOWNTO 0);
		disableCol				: out STD_LOGIC;
		CHVout				    : OUT STD_LOGIC_vector(C-1 Downto 0)
	);
	attribute DONT_TOUCH : string;
	attribute KEEP : string;
	attribute DONT_TOUCH of top_testCHVs : entity is "TRUE";
	attribute KEEP of top_testCHVs : entity is "TRUE";
END ENTITY top_testCHVs;

ARCHITECTURE behavioral OF top_testCHVs IS

--file mif_file : text open read_mode is integer'image(integer(classNumber))&"_"&integer'image(integer(classPortion))&".mif";


    component ECC_vhdl_module IS
        GENERIC (C  : INTEGER := 10 ;			----bit width number of classes or the segments size that we are going to correct
                ECC_bit		: INTEGER := 4  );	---- NUmber of bits for correction each column 
        Port (
            d   : in  std_logic_vector(C-1 downto 0);
            p   : in  std_logic_vector(ECC_bit-1 downto 0);
            double_error  : out std_logic;
            dcw  : out std_logic_vector(C-1 downto 0)
        );
    end component;
	COMPONENT popCount IS
		GENERIC (lenPop : INTEGER := 8);   -- bit width out popCounters --- LOG2(#feature)
		PORT (
			clk , rst 	: IN STD_LOGIC;
			en		 	: IN STD_LOGIC;
			dout        : OUT  STD_LOGIC_VECTOR (lenPop-1 DOWNTO 0)
		);
	END COMPONENT;	

    component xor_parity is
        Generic (
            c : integer := 8 -- Width of the CHV
        );
        Port (
            input_vector : in  std_logic_vector(c-1 downto 0); -- N-bit input
            parity       : in  std_logic;                     -- 1-bit parity input
            result       : out std_logic                      -- XOR result output
        );
    end component;
    
    component ROM_LUT_1 is
    Port (
        address : in STD_LOGIC_VECTOR(7 downto 0);
        data_out : out STD_LOGIC_VECTOR(4 downto 0) -- 5-bit value
    );
    end component ;
-- Define the type for an array of std_logic_vector
type ECC_memory_array is array (natural range <>) of std_logic_vector(ECC_bit-1 downto 0);

-- memory signal
signal ECCmemory : ECC_memory_array(Num_ECC_correctoin-1 DOWNTO 0); -- memory_depth is the number of lines in the file
constant paritymem : STD_LOGIC_VECTOR (Num_parity-1 DOWNTO 0) :=(others => '0');
signal flagmem : STD_LOGIC_VECTOR (2**n-1 DOWNTO 0);
-- File-related for memory
file ECCmif_file : text open read_mode is "ECC_memory_file_"&integer'image(integer(index))&".mif"; -- Specify your file name
file paritymif_file : text open read_mode is "parity_memory_"&integer'image(integer(index))&".mif"; -- Specify your file name
file flagmif_file : text open read_mode is "flag_memory_"&integer'image(integer(index))&".mif"; 

--file mif_file : text open read_mode is integer'image(integer(classNumber))&"_"&integer'image(integer(classPortion))&".mif";

-- memory pointers 
signal ECCPointer :STD_LOGIC_VECTOR(lenPointerToECC-1 Downto 0);
signal ParityPointer :STD_LOGIC_VECTOR(lenPointerToparity-1 Downto 0);
signal rstPointersPop : STD_LOGIC;

--memory outputs
signal prityOut :STD_logic;
signal flagOut :STD_logic;
SIGNAL ECCout  :std_logic_vector(ECC_bit-1 downto 0);
    
-- other signals 
signal ECCCHVout	:  STD_LOGIC_vector(C-1 Downto 0);
signal ECCDFF, ECCaply, pointerspop	:  STD_LOGIC;
Signal parityresult : std_logic;
Signal faultdetetcionmux1 : std_logic;
Signal selmuxDetection : std_logic;
Signal selmuxoutput : std_logic;
Signal notflag : std_logic;  -- enabeling counters for memory pointer
Signal flag : std_logic;  -- enabeling counters for memory pointer



attribute keep_hierarchy : string;
--attribute KEEP : string;
attribute keep_hierarchy of parity : label is "TRUE";
attribute keep_hierarchy of ECCDecoder : label is "TRUE";
attribute KEEP of flagmem : signal is "TRUE";
--attribute KEEP of paritymem : signal is "TRUE";
attribute KEEP of ECCmemory : signal is "TRUE";

attribute MARK_DEBUG : string;
attribute MARK_DEBUG of prityOut : signal is "TRUE";
attribute MARK_DEBUG of flag : signal is "TRUE";
attribute MARK_DEBUG of ECCout : signal is "TRUE";
attribute MARK_DEBUG of ParityPointer : signal is "TRUE";
attribute MARK_DEBUG of ECCPointer : signal is "TRUE";
attribute MARK_DEBUG of FlagPointer : signal is "TRUE";


BEGIN
	
    -- The process read the file for ECC check and store data in the signal
    process
	variable mif_line : line;
	variable temp_bv : bit_vector(ECC_bit-1 downto 0); -- Temporary buffer for each line

    begin
        -- Loop through each line of the file
        for i in 0 to Num_ECC_correctoin-1 loop
            if not endfile(ECCmif_file) then
                -- Read one line from the file
                readline(ECCmif_file, mif_line);
                -- Read the binary data into the temporary bit_vector
                read(mif_line, temp_bv);
                -- Convert the bit_vector to std_logic_vector and store it in the memory signal
                ECCmemory(i) <= to_stdlogicvector(temp_bv);
            else
                -- Handle end of file if fewer lines exist than expected
                ECCmemory(i) <= (others => '0'); -- Optional: Initialize remaining entries to 0
            end if;
        end loop;
        wait; -- Stop the process after reading the file
    end process; 

--    -- The process read the file for parity, which is only one string and bits are assigend for each parity
--    process
--	variable mif_line : line;
--	variable temp_bv : bit_vector(Num_parity-1 downto 0);
--	variable once_run : BOOLEAN := false;
--	begin
--		if (clk ='1' and clk'event)then
--			if once_run = false then
--                readline(paritymif_file, mif_line);
--                read(mif_line, temp_bv);
--                paritymem <= to_stdlogicvector (temp_bv);
--                once_run := true;
--            else 
--                once_run := true;
--            end if;
--		end if;
--        wait; -- Stop the process after reading the file
--	end process;
--     The process read the file for flag
    process
	variable mif_line : line;
	variable temp_bv : bit_vector(2**n-1 downto 0);
	variable once_run : BOOLEAN := false;
	begin
		if (clk ='1' and clk'event)then
			if once_run = false then
                readline(flagmif_file, mif_line);
                read(mif_line, temp_bv);
                flagmem <= to_stdlogicvector (temp_bv);
                once_run := true;
            else 
                once_run := true;
            end if;
		end if;
        wait; -- Stop the process after reading the file
	end process;
	prityOut  <= paritymem(to_integer(unsigned(ParityPointer)));
	flag      <= flagmem(to_integer(unsigned(FlagPointer)));
    ECCout    <= ECCmemory(to_integer(unsigned(ECCPointer)));
--    lut : ROM_LUT_1 
--    Port map(
--        ECCPointer,
--        ECCout
--    );
    notflag <= not(flag) and run;
    pointerspop <= flag and run;

    rstPointersPop <= rst or done or run;
--    rstPointersECC <= (rst or done) ;
    
    ECCMemPointer : popCount
		GENERIC MAP(lenPointerToECC)
		PORT MAP(
			clk , rstPointersPop , notflag, 
            ECCPointer
		); 
    
    ParityMemPointermodule : popCount
		GENERIC MAP(lenPointerToparity)
		PORT MAP(
			clk , rstPointersPop , pointerspop, 
            ParityPointer
		);            
    
    ECCDecoder : ECC_vhdl_module
        GENERIC MAP(C , ECC_bit )
        Port MAP(
            CHVin, ECCout,
            ECCDFF  , ECCCHVout
        );
    parity : xor_parity
        Generic map(  C  )
        Port map(
            CHVin, prityOut , parityresult
        );
    
        
    faultdetetcionmux1 <= parityresult WHEN (flag = '1') ELSE
                    ECCDFF ;
                    
    ECCaply <= flag; -- faultdetetcionmux1 or 
    
    CHVout <= ECCCHVout WHEN (ECCaply = '0') ELSE
            CHVin ;

    disableCol  <= not (flag and faultdetetcionmux1);

END ARCHITECTURE behavioral;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity xor_parity is
    Generic (
        c : integer := 8 -- Width of the CHV
    );
    Port (
        input_vector : in  std_logic_vector(c-1 downto 0); -- N-bit input
        parity       : in  std_logic;                     -- 1-bit parity input
        result       : out std_logic                      -- XOR result output
    );
end xor_parity;

architecture Behavioral of xor_parity is
begin
    process (input_vector, parity)
        variable xor_result : std_logic; -- Temporary variable for XOR result
    begin
        -- Initialize the XOR result to 0
        xor_result := '0';
        
        -- XOR all bits of the input vector
        for i in 0 to c-1 loop
            xor_result := xor_result xor input_vector(i);
        end loop;

        -- XOR the parity bit
        xor_result := xor_result xor parity;

        -- Assign the result to the output
        result <= xor_result;
        
    end process;
end Behavioral;

