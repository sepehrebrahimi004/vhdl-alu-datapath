-- Self-checking testbench for packet_checker (with and without the parity
-- bonus), using the three examples from the assignment plus regressions.
library ieee;
use ieee.std_logic_1164.all;
use work.tb_util.all;

entity tb_packet_checker is
end entity;

architecture sim of tb_packet_checker is
    signal clk            : std_logic := '0';
    signal rst            : std_logic := '1';
    signal valid          : std_logic := '0';
    signal packet         : std_logic_vector(31 downto 0) := (others => '0');
    signal en_p, err_p    : std_logic;                    -- parity checking on
    signal addr_p         : std_logic_vector(7 downto 0);
    signal data_p         : std_logic_vector(15 downto 0);
    signal en_n, err_n    : std_logic;                    -- parity checking off
    signal addr_n         : std_logic_vector(7 downto 0);
    signal data_n         : std_logic_vector(15 downto 0);
    signal finished       : boolean := false;
begin
    clk <= not clk after 5 ns when not finished;

    uut_parity : entity work.packet_checker
        generic map (PARITY_CHECK => true)
        port map (clk => clk, rst => rst, valid => valid, packet => packet, ram_en => en_p,
                  ram_address => addr_p, ram_data => data_p, error => err_p);

    uut_basic : entity work.packet_checker
        generic map (PARITY_CHECK => false)
        port map (clk => clk, rst => rst, valid => valid, packet => packet, ram_en => en_n,
                  ram_address => addr_n, ram_data => data_n, error => err_n);

    stimulus : process
        variable errors, checks : natural := 0;

        procedure send(p : std_logic_vector(31 downto 0)) is
        begin
            packet <= p;
            valid  <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            valid  <= '0';
        end procedure;
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
        rst <= '0';

        -- Example 1 (basic part): 1101 0010 0101 0101 1001 0001 1010
        send(x"0D25591A");
        check(en_n = '1' and addr_n = x"91" and data_n = x"D255" and err_n = '0',
              "example 1 (no parity): addr " & hex(addr_n) & " data " & hex(data_n), errors, checks);
        wait until rising_edge(clk);
        wait for 1 ns;
        check(en_n = '0', "ram_en must last one clock", errors, checks);

        -- Example 2 (bonus): correct check nibble 1100
        send(x"CD25591A");
        check(en_p = '1' and err_p = '0' and addr_p = x"91" and data_p = x"D255",
              "example 2 (parity ok)", errors, checks);

        -- Example 3 (bonus): bit 31 wrong -> error, no write
        send(x"4D25591A");
        check(en_p = '0' and err_p = '1', "example 3 (parity error)", errors, checks);
        wait until rising_edge(clk);
        wait for 1 ns;
        check(err_p = '0', "error must last one clock", errors, checks);

        -- Wrong header: ignored by both checkers
        send(x"CD25591B");
        check(en_p = '0' and err_p = '0' and en_n = '0', "wrong header ignored", errors, checks);

        -- Back-to-back packets (the original design accepted only the first)
        send(x"CD25591A");
        check(en_p = '1', "back-to-back packet 1", errors, checks);
        send(x"0000A12A");
        check(en_p = '1' and addr_p = x"12" and data_p = x"000A", "back-to-back packet 2", errors, checks);

        -- valid low: nothing happens even with a good packet on the bus
        packet <= x"CD25591A";
        wait until rising_edge(clk);
        wait for 1 ns;
        check(en_p = '0' and err_p = '0', "idle when valid = 0", errors, checks);

        summary("packet_checker", errors, checks);
        finished <= true;
        wait;
    end process;
end architecture;
