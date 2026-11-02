-- Integration test: ALU -> sequence detector -> packet checker.
library ieee;
use ieee.std_logic_1164.all;
use work.tb_util.all;

entity tb_datapath_top is
end entity;

architecture sim of tb_datapath_top is
    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal start         : std_logic := '0';
    signal a, b          : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_control   : std_logic_vector(2 downto 0) := "000";
    signal alu_y         : std_logic_vector(31 downto 0);
    signal alu_ready     : std_logic;
    signal c, o, n, z    : std_logic;
    signal detected      : std_logic;
    signal ram_en, error : std_logic;
    signal ram_address   : std_logic_vector(7 downto 0);
    signal ram_data      : std_logic_vector(15 downto 0);
    signal finished      : boolean := false;
begin
    clk <= not clk after 5 ns when not finished;

    uut : entity work.datapath_top
        port map (clk => clk, rst => rst, start => start, a => a, b => b, alu_control => alu_control,
                  alu_y => alu_y, alu_ready => alu_ready, c => c, o => o, n => n, z => z,
                  detected => detected, ram_en => ram_en, ram_address => ram_address,
                  ram_data => ram_data, error => error);

    stimulus : process
        variable errors, checks : natural := 0;
        variable n_en, n_err, n_det : natural;
        variable last_addr          : std_logic_vector(7 downto 0);
        variable last_data          : std_logic_vector(15 downto 0);

        -- launch one ALU operation and observe the pipeline for 80 cycles
        procedure transaction(op : std_logic_vector(2 downto 0); av, bv : std_logic_vector(31 downto 0)) is
        begin
            a <= av;
            b <= bv;
            alu_control <= op;
            start <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            start <= '0';
            n_en := 0; n_err := 0; n_det := 0;
            for i in 1 to 80 loop
                if ram_en = '1' then
                    n_en := n_en + 1;
                    last_addr := ram_address;
                    last_data := ram_data;
                end if;
                if error = '1' then
                    n_err := n_err + 1;
                end if;
                if detected = '1' then
                    n_det := n_det + 1;
                end if;
                wait until rising_edge(clk);
                wait for 1 ns;
            end loop;
        end procedure;
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
        rst <= '0';

        -- OR with 0 passes a valid packet that contains the code 0111_1101:
        -- check 1100 | data 7D03 | address 42 | header A
        transaction("110", x"C7D0342A", x"00000000");
        check(n_det = 2 and n_en = 1 and n_err = 0, "valid packet written once", errors, checks);
        check(last_addr = x"42" and last_data = x"7D03",
              "RAM address/data " & hex(last_addr) & "/" & hex(last_data), errors, checks);

        -- Same packet produced by an ADD (0xC7D00000 + 0x0000342A)
        transaction("001", x"C7D00000", x"0000342A");
        check(n_en = 1 and n_err = 0, "packet built by ADD", errors, checks);

        -- Wrong parity bit 31 -> error, no RAM write
        transaction("110", x"47D0342A", x"00000000");
        check(n_det = 2 and n_en = 0 and n_err = 1, "parity error reported", errors, checks);

        -- Result without the code is never forwarded, even with a valid header
        transaction("110", x"0000342A", x"00000000");
        check(n_det = 0 and n_en = 0 and n_err = 0, "no code -> no RAM access", errors, checks);

        summary("datapath_top", errors, checks);
        finished <= true;
        wait;
    end process;
end architecture;
