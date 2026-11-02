--------------------------------------------------------------------------------
-- seq_detector : FSM that finds the bit pattern 01111101 (0x7, 0xD) in a word
--
-- Phase 3. On 'start' the 32-bit word is loaded and scanned serially, MSB
-- first, one bit per clock. The Moore-style FSM state is the length of the
-- longest prefix of the pattern matched so far (KMP automaton), so
-- overlapping occurrences are found as well: after a full match the suffix
-- "01" is already a prefix of the next occurrence (state S_MATCH behaves
-- like S2).
--
-- 'detected' goes high for 2 clocks after each occurrence, or for 4 clocks
-- when the occurrence overlaps the previous one (back-to-back codes).
-- When the scan has finished and at least one occurrence was found, the
-- word is forwarded on data_out with a one-cycle out_valid pulse.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seq_detector is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;                       -- synchronous, active high
        start     : in  std_logic;
        y_in      : in  std_logic_vector(31 downto 0);
        detected  : out std_logic;
        data_out  : out std_logic_vector(31 downto 0);
        out_valid : out std_logic;
        busy      : out std_logic
    );
end entity;

architecture rtl of seq_detector is
    -- S<k>: the last k scanned bits equal the first k bits of 01111101
    type state_t is (S0, S1, S2, S3, S4, S5, S6, S7, S_MATCH);
    signal state       : state_t := S0;

    constant PATTERN_LEN : natural := 8;
    constant OVERLAP     : natural := 2;                -- shared "01"

    signal shreg       : std_logic_vector(31 downto 0) := (others => '0');
    signal word        : std_logic_vector(31 downto 0) := (others => '0');
    signal bits_left   : natural range 0 to 32 := 0;
    signal hold        : natural range 0 to 4 := 0;      -- remaining 'detected' cycles
    signal since_match : natural range 0 to 63 := 63;    -- bits since the last match
    signal found       : std_logic := '0';
    signal scanning    : std_logic := '0';

    function next_state(s : state_t; bit_in : std_logic) return state_t is
    begin
        case s is
            when S0      => if bit_in = '0' then return S1; else return S0; end if;
            when S1      => if bit_in = '1' then return S2; else return S1; end if;
            when S2      => if bit_in = '1' then return S3; else return S1; end if;
            when S3      => if bit_in = '1' then return S4; else return S1; end if;
            when S4      => if bit_in = '1' then return S5; else return S1; end if;
            when S5      => if bit_in = '1' then return S6; else return S1; end if;
            when S6      => if bit_in = '0' then return S7; else return S0; end if;
            when S7      => if bit_in = '1' then return S_MATCH; else return S1; end if;
            when S_MATCH => if bit_in = '1' then return S3; else return S1; end if;  -- = S2
        end case;
    end function;
begin
    process (clk)
        variable ns : state_t;
    begin
        if rising_edge(clk) then
            out_valid <= '0';
            if hold > 0 then
                hold <= hold - 1;
            end if;

            if rst = '1' then
                state    <= S0;
                scanning <= '0';
                found    <= '0';
                hold     <= 0;

            elsif start = '1' and scanning = '0' then
                shreg       <= y_in;
                word        <= y_in;
                bits_left   <= 32;
                state       <= S0;
                found       <= '0';
                since_match <= 63;
                scanning    <= '1';

            elsif scanning = '1' then
                if bits_left > 0 then
                    ns := next_state(state, shreg(31));
                    state     <= ns;
                    shreg     <= shreg(30 downto 0) & '0';
                    bits_left <= bits_left - 1;
                    if ns = S_MATCH then
                        found       <= '1';
                        since_match <= 0;
                        if since_match = PATTERN_LEN - OVERLAP - 1 then
                            hold <= 4;                       -- overlapping occurrence
                        else
                            hold <= 2;
                        end if;
                    elsif since_match < 63 then
                        since_match <= since_match + 1;
                    end if;
                elsif hold <= 1 then                         -- let 'detected' finish
                    scanning <= '0';
                    if found = '1' then
                        data_out  <= word;
                        out_valid <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    detected <= '1' when hold > 0 else '0';
    busy     <= scanning;
end architecture;
