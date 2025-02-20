-- MIT License

-- Copyright (c) 2024 m-spr

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE std.textio.ALL;

ENTITY countingSimTop  IS
	GENERIC (n : INTEGER := 10;		 --; 	-- bit-widths of memory pointer, counter and etc,,, 
			 d : INTEGER := 10;		 	 	-- number of confComp module
			 z		 : INTEGER := 0;		 -- zeropadding to 2** for RSA 
			 classNumber : INTEGER := 10; 		---- class number --- for memory image
			 logInNum : INTEGER := 3	);   -- MuxCell, ceilingLOG2(#popCounters)
	PORT (
		clk, rst, run  	: IN STD_LOGIC;	
		hv        		: IN  STD_LOGIC_VECTOR(d -1 DOWNTO 0);	
		done       		: OUT  STD_LOGIC;	
		pointer		 	: OUT STD_LOGIC_VECTOR(n-1 DOWNTO 0);	
		dout	 		: OUT  STD_LOGIC_VECTOR(classNumber*(n+logInNum)-1 DOWNTO 0)  	
	);
END ENTITY countingSimTop ;

ARCHITECTURE behavioral OF countingSimTop IS

component countingSim  IS
	GENERIC (n : INTEGER := 10;		 --; 	-- bit-widths of memory pointer, counter and etc,,, 
			 d : INTEGER := 10;		 	 	-- number of confComp module
			 z		 : INTEGER := 0;		 -- zeropadding to 2** for RSA 
			 classNumber : INTEGER := 10; 		---- class number --- for memory image
			 logInNum : INTEGER := 3	);   -- MuxCell, ceilingLOG2(#popCounters OR d)
	PORT (
		clk, rst, run, done  	: IN STD_LOGIC;				---- run shuld be always '1' during calculation --- ctrl ---- 
		disable	:  IN STD_LOGIC_VECTOR (d-1 DOWNTO 0) ;				---- for seccurity 
		reg1Update, reg1rst, reg2Update, reg2rst   	: IN STD_LOGIC;				---- run shuld be always '1' during calculation --- ctrl ---- 
		muxSel   	 	: IN  STD_LOGIC_VECTOR (logInNum DOWNTO 0);
		hv        		: IN  STD_LOGIC_VECTOR(d -1 DOWNTO 0);
		CHV        		: IN  STD_LOGIC_VECTOR(d -1 DOWNTO 0);
		pointer		 	: IN STD_LOGIC_VECTOR(n-1 DOWNTO 0);	
		dout	 		: OUT  STD_LOGIC_VECTOR(n+logInNum-1 DOWNTO 0)  	
	);
end component;

component SeqAdderCtrl IS
	GENERIC (ceilingLogPop : INTEGER := 3;   -- ceilingLOG2(#popCounters)
			nPop : INTEGER := 8 );			-- #popCounters
	PORT (
		clk, rst 				: IN STD_LOGIC;
		run		 				: IN STD_LOGIC;
		reg1Update, reg1rst 	: OUT STD_LOGIC;
		reg2Update, reg2rst 	: OUT STD_LOGIC;
		muxSel 					: OUT STD_LOGIC_VECTOR(ceilingLogPop DOWNTO 0)
	);
end component;
 
component countingSimCtrl IS
	GENERIC (n : INTEGER := 10 ); --- bit pointer to memory
	PORT (
		clk, rst 				: IN STD_LOGIC;
		run		 				: IN STD_LOGIC;
		runOut, done 			: OUT STD_LOGIC;
		pointer 				: OUT STD_LOGIC_VECTOR(n-1 DOWNTO 0) --- As of now only support up to 16 classes so 4'bits 
	);
end component;

component top_testCHVs IS
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
END component;

--new memory signals
type CHV_memory is array (classNumber-1 downto 0) of std_logic_vector(1023 downto 0);
type CHV_memory_tosim is array (classNumber-1 downto 0) of std_logic_vector(d-1 downto 0);
type CHV_memory_toECC is array (d-1 downto 0) of std_logic_vector(classNumber-1 downto 0);
signal CHV_TO_OUT : CHV_memory_tosim;
signal CHV_FROM_ECC_TO_OUT : CHV_memory_tosim;
signal CHV_TO_ECC : CHV_memory_toECC;
signal CHV_FROM_ECC : CHV_memory_toECC;

signal CHV : CHV_memory;
signal CHV_TOdiv : CHV_memory_tosim;
signal addrtoCHV : STD_LOGIC_VECTOR(3 DOWNTO 0);
file CHV_file : text open read_mode is "CHV_img.mif"; -- Specify your file name

SIGNAL dones, runOut	: STD_LOGIC;				---- run shuld be always '1' during calculation --- ctrl ---- 
SIGNAL reg1Update, reg1rst, reg2Update, reg2rst, ECCCdetection	: STD_LOGIC;				---- run shuld be always '1' during calculation --- ctrl ---- 
SIGNAL muxSel	:  STD_LOGIC_VECTOR (logInNum DOWNTO 0);
SIGNAL disable	:  STD_LOGIC_VECTOR (d-1 DOWNTO 0);
SIGNAL point	: STD_LOGIC_VECTOR(n-1 DOWNTO 0);

attribute MARK_DEBUG : string;
attribute MARK_DEBUG of CHV : signal is "TRUE";
attribute MARK_DEBUG of CHV_TO_OUT : signal is "TRUE";
attribute MARK_DEBUG of CHV_FROM_ECC_TO_OUT : signal is "TRUE";
attribute MARK_DEBUG of CHV_TO_ECC : signal is "TRUE";
attribute MARK_DEBUG of CHV_FROM_ECC : signal is "TRUE";
--attribute MARK_DEBUG of addrtoCHV : signal is "TRUE";
--attribute MARK_DEBUG of CHV_TO_OUT : signal is "TRUE";
attribute DONT_TOUCH : string;
attribute DONT_TOUCH of testmodules : label is "TRUE";

begin

    process
	variable mif_line : line;
	variable temp_bv : bit_vector(1023 downto 0); -- Temporary buffer for each line
    begin
        -- Loop through each line of the file
        for i in 0 to classNumber-1 loop
            if not endfile(CHV_file) then
                -- Read one line from the file
                readline(CHV_file, mif_line);
                -- Read the binary data into the temporary bit_vector
                read(mif_line, temp_bv);
                -- Convert the bit_vector to std_logic_vector and store it in the memory signal
                CHV(i) <= to_stdlogicvector(temp_bv);
            else
                -- Handle end of file if fewer lines exist than expected
                CHV(i) <= (others => '0'); -- Optional: Initialize remaining entries to 0
            end if;
        end loop;
        wait; -- Stop the process after reading the file
    end process; 

    concatECC: FOR I IN classNumber-1 DOWNTO 0 GENERATE
        classesECC: FOR k IN d-1 DOWNTO 0 GENERATE
            CHV_TO_OUT(I)(k) <= CHV(I)(to_integer(unsigned(point)) + (2**n) * K);
        END GENERATE classesECC;
    END GENERATE concatECC;
--    process
--    begin
      reverce1 :   for i in 0 to d-1 generate
      reverce1in :       for j in 0 to classNumber-1 generate
                CHV_TO_ECC(i)(j) <= CHV_TO_OUT(j)(i);
            END GENERATE reverce1in;
       END GENERATE reverce1;
       
      reverce2 :   for j in 0 to d-1 generate
      reverce2in :  for i in 0 to classNumber-1 generate
                CHV_FROM_ECC_TO_OUT(i)(j) <= CHV_FROM_ECC(j)(i);
            END GENERATE reverce2in;
       END GENERATE reverce2;
--        wait; -- Prevent the process from running continuously
--    end process;
	AdderCtrl : SeqAdderCtrl
	GENERIC MAP(logInNum, 
			d )
	PORT MAP(
            clk, rst,
            dones,
            reg1Update, reg1rst,
            reg2Update, reg2rst,
            muxSel
        );	
	
            
    testmodules: FOR I  IN d-1 DOWNTO 0 GENERATE
        test1 : top_testCHVs 
        GENERIC map ( 10, n, I, 179, 337, 8, 9, 5  )
        PORT map(
            clk, rst, runOut, reg2Update, CHV_TO_ECC(I),point, disable(I), CHV_FROM_ECC(I)
        );
	END GENERATE testmodules;
    
	countSimArr: FOR I IN classNumber-1 DOWNTO 0 GENERATE
		comp : countingSim 
		GENERIC MAP(n ,d, z, I, logInNum)
		PORT MAP(
			clk, rst, runOut, dones, disable, 
			reg1Update, reg1rst, reg2Update, reg2rst,
			muxSel,
			hv, CHV_FROM_ECC_TO_OUT(I),
			point,
			dout(((I+1)*(n+logInNum))- 1 DOWNTO ((I)*(n+logInNum)))
		);
	END GENERATE countSimArr;
		
	CompCtrl : countingSimCtrl
	GENERIC MAP(n)
	PORT MAp(
		clk, rst,
		run,
		runOut, dones, 
		point
	);
	
	pointer <= point;
	done <= reg2Update;
	
end architecture;



