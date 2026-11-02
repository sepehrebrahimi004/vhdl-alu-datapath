-- Self-checking testbench for seq_detector. The 'detected' output is sampled
-- once per scanned bit and compared, position by position, with the
-- waveforms given in the assignment.
library ieee;
use ieee.std_logic_1164.all;
use work.tb_util.all;

entity tb_seq_detector is
end entity;

architecture sim of tb_seq_detector is
    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';
    signal start     : std_logic := '0';
    signal y_in      : std_logic_vector(31 downto 0) := (others => '0');
    signal detected  : std_logic;
    signal data_out  : std_logic_vector(31 downto 0);
    signal out_valid : std_logic;
    signal busy      : std_logic;
    signal finished  : boolean := false;

    constant N : natural := 40;                          -- 32 bits + tail
begin
    clk <= not clk after 5 ns when not finished;

    uut : entity work.seq_detector
        port map (clk => clk, rst => rst, start => start, y_in => y_in, detected => detected,
                  data_out => data_out, out_valid => out_valid, busy => busy);

    stimulus : process
        variable errors, checks : natural := 0;

        -- expected: detected per bit position (MSB first), padded with '0'
        procedure scan(word : std_logic_vector(31 downto 0); expected : string;
                       expect_forward : boolean; name : string) is
            variable got       : string(1 to N);
            variable exp_full  : string(1 to N) := (others => '0');
            variable forwarded : boolean := false;
            variable k         : natural := 0;
        begin
            for i in expected'range loop                 -- strip spaces from the pattern
                if expected(i) /= ' ' then
                    k := k + 1;
                    exp_full(k) := expected(i);
                end if;
            end loop;
            y_in  <= word;
            start <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            start <= '0';
            for pos in 1 to N loop
                got(pos) := std_logic'image(detected)(2);
                if out_valid = '1' then
                    forwarded := true;
                    check(data_out = word, name & ": data_out = " & hex(data_out), errors, checks);
                end if;
                wait until rising_edge(clk);
                wait for 1 ns;
            end loop;
            check(got = exp_full, name & ": detected" & LF & "  got      " & got & LF &
                  "  expected " & exp_full, errors, checks);
            check(forwarded = expect_forward, name & ": data forwarding", errors, checks);
            while busy = '1' loop
                wait until rising_edge(clk);
                wait for 1 ns;
            end loop;
        end procedure;
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
        rst <= '0';

        -- Assignment example 1
        scan(x"27D0EAB1", "0000 0000 0000 1100 0000 0000 0000 0000", true, "spec example 1");
        -- Assignment example 2 (bonus: overlapping codes -> 4-cycle pulse)
        scan(x"7DF5FB42", "0000 0000 1100 0011 1100 0000 0000 0000", true, "spec example 2");
        -- No occurrence: nothing is forwarded
        scan(x"00000000", "", false, "no match (zeros)");
        scan(x"FFFFFFFF", "", false, "no match (ones)");
        -- Code in the last byte: the pulse continues after the 32 bits
        scan(x"0000007D", "0000 0000 0000 0000 0000 0000 0000 0000 11", true, "match at end");
        -- Code with a gap (not overlapping): two separate 2-cycle pulses
        scan(x"7D07D000", "0000 0000 1100 0000 0000 1100 0000 0000", true, "two separate codes");

        summary("seq_detector", errors, checks);
        finished <= true;
        wait;
    end process;
end architecture;
