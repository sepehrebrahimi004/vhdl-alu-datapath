--------------------------------------------------------------------------------
-- multiplier16 : sequential shift-and-add multiplier, 16 x 16 -> 32 bit unsigned
--
-- Phase 1. Only the low 16 bits of a and b are used (the ALU feeds 32-bit
-- operands). On 'start' the operands are loaded and the product register is
-- cleared; then, for 16 clock cycles, the multiplicand is added to the product
-- when the multiplier LSB is 1, the multiplicand shifts left and the
-- multiplier shifts right. 'ready' pulses for one clock when y is valid.
--
-- Latency: 16 clock cycles after the cycle in which start is sampled.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity multiplier16 is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;                        -- synchronous, active high
        start : in  std_logic;
        a     : in  std_logic_vector(31 downto 0);    -- multiplicand (bits 15..0 used)
        b     : in  std_logic_vector(31 downto 0);    -- multiplier   (bits 15..0 used)
        y     : out std_logic_vector(31 downto 0);
        ready : out std_logic;
        busy  : out std_logic
    );
end entity;

architecture rtl of multiplier16 is
    signal multiplicand : unsigned(31 downto 0) := (others => '0');
    signal multiplier   : unsigned(15 downto 0) := (others => '0');
    signal product      : unsigned(31 downto 0) := (others => '0');
    signal count        : unsigned(3 downto 0)  := (others => '0');
    signal running      : std_logic := '0';
begin
    process (clk)
    begin
        if rising_edge(clk) then
            ready <= '0';
            if rst = '1' then
                running <= '0';
                product <= (others => '0');
                count   <= (others => '0');
            elsif start = '1' then
                multiplicand <= x"0000" & unsigned(a(15 downto 0));
                multiplier   <= unsigned(b(15 downto 0));
                product      <= (others => '0');
                count        <= (others => '0');
                running      <= '1';
            elsif running = '1' then
                if multiplier(0) = '1' then
                    product <= product + multiplicand;
                end if;
                multiplicand <= shift_left(multiplicand, 1);
                multiplier   <= shift_right(multiplier, 1);
                count        <= count + 1;
                if count = 15 then
                    running <= '0';
                    ready   <= '1';
                end if;
            end if;
        end if;
    end process;

    y    <= std_logic_vector(product);
    busy <= running;
end architecture;
