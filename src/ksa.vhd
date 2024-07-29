-- TOP LEVEL MODULE FOR RC4 DECODER
-- No core functionality is implemented here

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ksa is
  port(
    CLOCK_50            : in  std_logic;  -- Clock pin
    KEY                 : in  std_logic_vector(3 downto 0);  -- push button switches
    SW                 : in  std_logic_vector(9 downto 0);  -- slider switches
    LEDR : out std_logic_vector(9 downto 0);  -- red lights
    HEX0 : out std_logic_vector(6 downto 0);
    HEX1 : out std_logic_vector(6 downto 0);
    HEX2 : out std_logic_vector(6 downto 0);
    HEX3 : out std_logic_vector(6 downto 0);
    HEX4 : out std_logic_vector(6 downto 0);
    HEX5 : out std_logic_vector(6 downto 0));
end ksa;

architecture rtl of ksa is
    -- clock and reset signals  
	signal clk, reset_n, reset: std_logic;	

    -- all signals of nOut that is fed into SevenSegmentDisplayDecoder
    -- 2D array of 6 4-bit signals => 6 displays of HEX numbers
    type nOutArray is array(0 to 5) of std_logic_vector(3 downto 0);
    signal nOut: nOutArray;
    type HEX_Array is array(0 to 5) of std_logic_vector(6 downto 0);
    signal HEX: HEX_Array;

    -- SevenSegmentDisplayDecoder module component
    COMPONENT SevenSegmentDisplayDecoder IS
    PORT
    (
        ssOut : OUT STD_LOGIC_VECTOR (6 DOWNTO 0);
        nIn : IN STD_LOGIC_VECTOR (3 DOWNTO 0)
    );
    END COMPONENT;
   
    -- core module component for RC4_Decoder cores
    COMPONENT RC4_Decoder is 
     PORT 
     (
        SW : IN std_logic_vector(9 DOWNTO 0);
        KEY : IN std_logic_vector(3 DOWNTO 0);
        nOut : OUT nOutArray;
        LEDR : OUT std_logic_vector(9 DOWNTO 0);
        clk, reset : IN std_logic);
     END COMPONENT;

begin -- begin for architecture
    -- instantiate SevenSegmentDisplayDecoder module for all 6 HEX displays

    S_SEG_DEC_GEN: for index in 0 to 5 generate
        HEX_INST : SevenSegmentDisplayDecoder PORT MAP (ssOut => HEX(index), 
                                                        nIn => nOut(index));
    end generate S_SEG_DEC_GEN;
    
    -- instantiate RC4_Decoder module (any number of cores)
    RC4_Decoder_INST : RC4_Decoder PORT MAP (SW => SW,
                                             KEY => KEY,
                                             LEDR => LEDR,
                                             nOut => nOut,
                                             clk => clk, 
                                             reset => reset);

    -- clock and reset signals assigns
    clk <= CLOCK_50;
    reset_n <= KEY(3);
    reset <= not reset_n;

    -- HEX signals assigns
    HEX0 <= HEX(0);
    HEX1 <= HEX(1);
    HEX2 <= HEX(2);
    HEX3 <= HEX(3);
    HEX4 <= HEX(4);
    HEX5 <= HEX(5);
end rtl;