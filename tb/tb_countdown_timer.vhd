-- Self-checking testbench for countdown_timer. CLK_HZ is set to 4 so one
-- "second" lasts four clock cycles and the test runs quickly.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tb_util.all;

entity tb_countdown_timer is
end entity;

architecture sim of tb_countdown_timer is
    constant CLK_HZ  : positive := 4;
    signal clk       : std_logic := '0';
    signal rst_n     : std_logic := '0';
    signal load      : std_logic := '0';
    signal min_in    : unsigned(5 downto 0) := (others => '0');
    signal sec_in    : unsigned(5 downto 0) := (others => '0');
    signal minutes   : unsigned(5 downto 0);
    signal seconds   : unsigned(5 downto 0);
    signal done      : std_logic;
    signal finished  : boolean := false;
begin
    clk <= not clk after 5 ns when not finished;

    uut : entity work.countdown_timer
        generic map (CLK_HZ => CLK_HZ)
        port map (clk => clk, rst_n => rst_n, load => load, minutes_in => min_in,
                  seconds_in => sec_in, minutes => minutes, seconds => seconds, done => done);

    stimulus : process
        variable errors, checks : natural := 0;
        variable cycles         : natural;

        procedure start_timer(m, s : natural) is
        begin
            min_in <= to_unsigned(m, 6);
            sec_in <= to_unsigned(s, 6);
            load   <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            load   <= '0';
        end procedure;

        procedure run_until_done(limit : natural) is
        begin
            cycles := 0;
            while done = '0' and cycles < limit loop
                wait until rising_edge(clk);
                wait for 1 ns;
                cycles := cycles + 1;
            end loop;
        end procedure;
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
        rst_n <= '1';

        -- 0:03 -> done after exactly 3 s
        start_timer(0, 3);
        check(minutes = 0 and seconds = 3 and done = '0', "load 0:03", errors, checks);
        run_until_done(100);
        check(done = '1' and cycles = 3 * CLK_HZ,
              "0:03 done after " & integer'image(cycles) & " cycles", errors, checks);

        -- 2:45 (assignment example) -> minutes roll over correctly
        start_timer(2, 45);
        for i in 1 to 46 * CLK_HZ loop                  -- 46 s later: 1:59
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;
        check(minutes = 1 and seconds = 59, "2:45 - 46 s = " & integer'image(to_integer(minutes)) &
              ":" & integer'image(to_integer(seconds)), errors, checks);
        run_until_done(200 * CLK_HZ);
        check(done = '1' and cycles = (165 - 46) * CLK_HZ, "2:45 done on time", errors, checks);
        check(minutes = 0 and seconds = 0, "stops at 0:00", errors, checks);
        for i in 1 to 3 * CLK_HZ loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;
        check(done = '1' and seconds = 0, "stays done", errors, checks);

        -- 0:00 -> done immediately
        start_timer(0, 0);
        check(done = '1', "0:00 done immediately", errors, checks);

        -- synchronous active-low reset in the middle of a countdown
        start_timer(0, 30);
        for i in 1 to 2 * CLK_HZ loop
            wait until rising_edge(clk);
        end loop;
        rst_n <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        check(minutes = 0 and seconds = 0 and done = '0', "reset clears the timer", errors, checks);
        rst_n <= '1';

        summary("countdown_timer", errors, checks);
        finished <= true;
        wait;
    end process;
end architecture;
