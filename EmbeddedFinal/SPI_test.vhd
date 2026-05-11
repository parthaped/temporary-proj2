----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/05/2026 06:22:31 PM
-- Design Name: 
-- Module Name: SPI_test - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-- Lightweight hardware smoke-test wrapper for SPI_Controller.
-- This is NOT the simulation testbench (see SPI_tb.vhd for that). It is just
-- enough glue to push the SPI_Controller onto a board with two buttons
-- (reset, read_en) and watch chip_sel / data_out on logic analyser pins.
entity SPI_test is
  Port (clk, reset, read_en : in std_logic;
        data_in    : in std_logic;
        sclk       : out std_logic; -- SPI_Controller now generates this internally
        chip_sel   : out std_logic;
        data_ready : out std_logic;
        data_out   : out std_logic_vector(11 downto 0));
end SPI_test;

architecture Behavioral of SPI_test is
    -- Component declaration must match the entity in SPI_Controller.vhd EXACTLY.
    -- The old declaration treated sclk as an input and was missing data_ready
    -- and next_sample, which made this file fail to elaborate.
    component SPI_Controller port(
        clk         : in  std_logic;
        sclk        : out std_logic;
        reset       : in  std_logic;
        read_en     : in  std_logic;
        data_in_1   : in  std_logic;
        data_in_2   : in  std_logic;
        chip_sel    : out std_logic;
        data_ready  : out std_logic;
        next_sample : out std_logic;
        data_out_1  : out std_logic_vector(11 downto 0);
        data_out_2  : out std_logic_vector(11 downto 0)
    ); end component;

    component debouncer port(
        clk, btn  : in  std_logic;
        db_signal : out std_logic
    ); end component;

    -- NOTE: the old code referenced a `Clock_div` entity that does not exist
    -- in this project. The SPI_Controller has its own internal divider that
    -- produces a 12.5 MHz sclk from the 125 MHz clk, so no external divider
    -- is needed here. (The closest existing divider, clk_div_vga, produces a
    -- 25 MHz one-cycle ENABLE PULSE, not a free-running clock, which is why
    -- it is not appropriate to feed in here either.)

    signal reset_db, read_db : std_logic;

begin

    SPI : SPI_Controller port map(
        clk         => clk,
        sclk        => sclk,
        reset       => reset_db,
        read_en     => read_db,
        data_in_1   => data_in,
        data_in_2   => '0',
        chip_sel    => chip_sel,
        data_ready  => data_ready,
        next_sample => open,
        data_out_1  => data_out,
        data_out_2  => open
    );

    reset_debounce : debouncer port map(
        clk       => clk,
        btn       => reset,
        db_signal => reset_db
    );

    read_debounce : debouncer port map(
        clk       => clk,
        btn       => read_en,
        db_signal => read_db
    );

end Behavioral;
