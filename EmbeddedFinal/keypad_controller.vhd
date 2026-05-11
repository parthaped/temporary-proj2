----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/10/2026 10:45:50 PM
-- Design Name: 
-- Module Name: keypad_controller - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity keypad_controller is
 Port (clk: in std_logic;
 
        --PMOD Pins
        rows: in std_logic_vector(3 downto 0);
        cols: out std_logic_vector(3 downto 0);
        
        --signals to pass to pixel pusher
        key_valid: out std_logic;
        key_data: out std_logic_vector(3 downto 0)
 
  );
end keypad_controller;

architecture Behavioral of keypad_controller is

    -- 1 kHz scan tick (one tick every 1 ms at 125 MHz)
    signal scan_timer : integer range 0 to 125000 := 0;
    signal scan_tick  : std_logic := '0';

    type state_type is (SCAN_C1, SCAN_C2, SCAN_C3, SCAN_C4, WAIT_RELEASE);
    signal current_state : state_type := SCAN_C1;

begin

    -- Drive cols COMBINATIONALLY from the current state. The new column
    -- pattern appears on the Pmod pins as soon as the state changes, so
    -- the rows have ~1 ms of settling time before the next scan_tick.
    -- (The old registered scheme made rows sample the previous column.)
    --
    -- WAIT_RELEASE drives all four cols LOW: that way ANY key still being
    -- held will keep at least one row pulled low, so rows /= "1111" until
    -- the user actually lets go.
    with current_state select
        cols <= "0111" when SCAN_C1,
                "1011" when SCAN_C2,
                "1101" when SCAN_C3,
                "1110" when SCAN_C4,
                "0000" when WAIT_RELEASE,
                "1111" when others;

    -- 1 kHz tick generator
    process(clk)
    begin
        if rising_edge(clk) then
            if scan_timer = 125000 then
                scan_timer <= 0;
                scan_tick  <= '1';
            else
                scan_timer <= scan_timer + 1;
                scan_tick  <= '0';
            end if;
        end if;
    end process;

    -- Matrix scanning FSM. Rows are decoded directly with a case
    -- statement in the same scan tick, so there is no stale "key_pressed"
    -- carrying across into the WAIT_RELEASE -> SCAN_C1 transition.
    process(clk)
    begin
        if rising_edge(clk) then
            -- key_valid is a single-cycle pulse by default
            key_valid <= '0';

            if scan_tick = '1' then
                case current_state is

                    when SCAN_C1 =>
                        case rows is
                            when "0111" => key_data <= x"1"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1011" => key_data <= x"4"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1101" => key_data <= x"7"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1110" => key_data <= x"0"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when others => current_state <= SCAN_C2;
                        end case;

                    when SCAN_C2 =>
                        case rows is
                            when "0111" => key_data <= x"2"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1011" => key_data <= x"5"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1101" => key_data <= x"8"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1110" => key_data <= x"F"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when others => current_state <= SCAN_C3;
                        end case;

                    when SCAN_C3 =>
                        case rows is
                            when "0111" => key_data <= x"3"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1011" => key_data <= x"6"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1101" => key_data <= x"9"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1110" => key_data <= x"E"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when others => current_state <= SCAN_C4;
                        end case;

                    when SCAN_C4 =>
                        case rows is
                            when "0111" => key_data <= x"A"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1011" => key_data <= x"B"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1101" => key_data <= x"C"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when "1110" => key_data <= x"D"; key_valid <= '1'; current_state <= WAIT_RELEASE;
                            when others => current_state <= SCAN_C1;
                        end case;

                    when WAIT_RELEASE =>
                        -- All four cols are driven LOW (see the cols mux above),
                        -- so any key still held pulls some row low and rows /= "1111".
                        -- Only when every key is released does rows return to "1111".
                        if rows = "1111" then
                            current_state <= SCAN_C1;
                        end if;

                end case;
            end if;
        end if;
    end process;
end Behavioral;
