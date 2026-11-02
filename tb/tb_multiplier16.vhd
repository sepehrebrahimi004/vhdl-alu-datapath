-- Self-checking testbench for multiplier16: corner cases, back-to-back
-- operations and 200 random products against numeric_std multiplication.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.tb_util.all;

entity tb_multiplier16 is
end entity;

architecture sim of tb_multiplier16 is
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal start    : std_logic := '0';
    signal a, b, y  : std_logic_vector(31 downto 0) := (others => '0');
    signal ready    : std_logic;
    signal busy     : std_logic;
    signal finished : boolean := false;
begin
    clk <= not clk after 5 ns when not finished;

    uut : entity work.multiplier16
        port map (clk => clk, rst => rst, start => start, a => a, b => b,
                  y => y, ready => ready, busy => busy);

    stimulus : process
        variable errors, checks : natural := 0;
        variable seed1, seed2   : positive := 42;
        variable r              : real;
        variable x1, x2         : natural;

        procedure multiply(av, bv : natural; upper_garbage : boolean := false) is
            variable expected : unsigned(31 downto 0);
            variable cycles   : natural := 0;
        begin
            a <= std_logic_vector(to_unsigned(av, 32));
            b <= std_logic_vector(to_unsigned(bv, 32));
            if upper_garbage then                       -- upper halves must be ignored
                a(31 downto 16) <= x"DEAD";
                b(31 downto 16) <= x"BEEF";
            end if;
            start <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            start <= '0';
            loop
                wait until rising_edge(clk);
                wait for 1 ns;
                cycles := cycles + 1;
                exit when ready = '1' or cycles > 40;
            end loop;
            expected := to_unsigned(av, 16) * to_unsigned(bv, 16);
            check(ready = '1', "ready never asserted", errors, checks);
            check(cycles = 16, "latency " & integer'image(cycles) & " /= 16", errors, checks);
            check(unsigned(y) = expected, integer'image(av) & " * " & integer'image(bv) &
                  " = " & hex(y) & ", expected " & hex(std_logic_vector(expected)), errors, checks);
            wait until rising_edge(clk);
            wait for 1 ns;
            check(ready = '0', "ready longer than one cycle", errors, checks);
            check(unsigned(y) = expected, "product not held", errors, checks);
        end procedure;
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
        rst <= '0';

        multiply(6, 3);                                  -- original testbench case
        multiply(0, 12345);
        multiply(12345, 0);
        multiply(1, 65535);
        multiply(65535, 65535);                          -- largest input (assignment)
        multiply(40000, 50000, upper_garbage => true);
        multiply(7, 9);                                  -- back-to-back reuse
        for i in 1 to 200 loop
            uniform(seed1, seed2, r); x1 := integer(trunc(r * 65535.0));
            uniform(seed1, seed2, r); x2 := integer(trunc(r * 65535.0));
            multiply(x1, x2);
        end loop;

        summary("multiplier16", errors, checks);
        finished <= true;
        wait;
    end process;
end architecture;
